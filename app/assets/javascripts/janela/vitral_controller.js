import { Controller } from "@hotwired/stimulus"

// Draws vitral's leadlight and lets it answer the pointer: every node leans
// toward the cursor, hardest nearby and not at all far away, then settles back
// when it leaves. A window made of data, which is the only excuse for an
// effect on a page about dashboards.
//
// Optional in every sense. The theme is complete without it, the stylesheet
// carries a static lattice for anyone who never loads this, Janela's own pages
// never load it, and a visitor who has asked for less motion gets a still one.
export default class extends Controller {
  static values = {
    columns: { type: Number, default: 17 },
    rows: { type: Number, default: 13 },
    reach: { type: Number, default: 260 },   // how far the pull carries, in pixels
    pull: { type: Number, default: 26 }      // how far a node nearest the cursor travels
  }

  connect() {
    this.canvas = document.createElement("canvas")
    this.canvas.className = "vitral-lattice"
    this.canvas.setAttribute("aria-hidden", "true")
    document.body.prepend(this.canvas)
    this.pen = this.canvas.getContext("2d")
    this.element.classList.add("vitral-live")

    this.still = window.matchMedia("(prefers-reduced-motion: reduce)").matches ||
                 !window.matchMedia("(hover: hover)").matches

    this.onResize = this.onResize.bind(this)
    this.onMove = this.onMove.bind(this)
    this.onLeave = this.onLeave.bind(this)

    // Decoration waits its turn. Cutting the glass is a few hundred polygons,
    // and a dashboard's first paint and its frames matter more than a
    // background does, so the first draw happens once the browser is idle.
    this.idle = window.requestIdleCallback
      ? requestIdleCallback(() => this.cut(), { timeout: 600 })
      : setTimeout(() => this.cut(), 120)

    window.addEventListener("resize", this.onResize, { passive: true })
    if (!this.still) {
      window.addEventListener("pointermove", this.onMove, { passive: true })
      document.addEventListener("pointerleave", this.onLeave)
    }
  }

  disconnect() {
    window.removeEventListener("resize", this.onResize)
    window.removeEventListener("pointermove", this.onMove)
    document.removeEventListener("pointerleave", this.onLeave)
    cancelAnimationFrame(this.frame)
    if (window.cancelIdleCallback && this.idle) cancelIdleCallback(this.idle)
    clearTimeout(this.resizing)
    this.canvas?.remove()
    this.element.classList.remove("vitral-live")
  }

  // Cutting the glass: a jittered grid of nodes, then cells over them, some
  // cut across the diagonal the way a real window is. Seeded, so the same
  // window is cut every time rather than a new one on every load.
  cut() {
    const random = seeded(1912)
    const width = this.canvas.width = Math.ceil(window.innerWidth * devicePixelRatio)
    const height = this.canvas.height = Math.ceil(window.innerHeight * devicePixelRatio)
    this.canvas.style.width = `${window.innerWidth}px`
    this.canvas.style.height = `${window.innerHeight}px`
    this.pen.scale(devicePixelRatio, devicePixelRatio)

    const w = width / devicePixelRatio, h = height / devicePixelRatio
    const cols = this.columnsValue, rows = this.rowsValue
    const cw = w / cols, ch = h / rows

    this.nodes = []
    const index = (r, c) => r * (cols + 1) + c
    for (let r = 0; r <= rows; r++) {
      for (let c = 0; c <= cols; c++) {
        const edge = c === 0 || c === cols || r === 0 || r === rows
        const x = c * cw + (edge ? 0 : (random() - 0.5) * 0.64 * cw)
        const y = r * ch + (edge ? 0 : (random() - 0.5) * 0.64 * ch)
        this.nodes.push({ home: [ x, y ], at: [ x, y ] })
      }
    }

    const tints = [ "58,122,235", "28,168,158", "240,176,70", "224,96,130", "138,110,228" ]
    this.cells = []
    for (let r = 0; r < rows; r++) {
      for (let c = 0; c < cols; c++) {
        const a = index(r, c), b = index(r, c + 1), d = index(r + 1, c + 1), e = index(r + 1, c)
        const quads = random() < 0.45
          ? (random() < 0.5 ? [ [ a, b, d ], [ a, d, e ] ] : [ [ a, b, e ], [ b, d, e ] ])
          : [ [ a, b, d, e ] ]
        for (const corners of quads) {
          const tint = random() < 0.3
            ? `rgba(${tints[Math.floor(random() * tints.length)]}, ${(0.04 + random() * 0.05).toFixed(3)})`
            : null
          this.cells.push({ corners, tint })
        }
      }
    }

    this.draw()
  }

  onResize() {
    clearTimeout(this.resizing)
    this.resizing = setTimeout(() => this.cut(), 150)
  }

  onMove(event) {
    this.pointer = [ event.clientX, event.clientY ]
    this.element.style.setProperty("--vitral-shift-x", (event.clientX / window.innerWidth - 0.5).toFixed(3))
    this.element.style.setProperty("--vitral-shift-y", (event.clientY / window.innerHeight - 0.5).toFixed(3))
    this.start()
  }

  onLeave() {
    this.pointer = null
    this.start()
  }

  start() {
    if (this.frame) return
    this.frame = requestAnimationFrame(() => this.step())
  }

  // Each node eases toward where the pointer wants it, so the glass leans and
  // settles rather than snapping. The loop stops once nothing is moving,
  // because a background that animates forever is a laptop fan.
  step() {
    this.frame = null
    if (!this.nodes) return

    let moving = false

    for (const node of this.nodes) {
      const [ hx, hy ] = node.home
      let tx = hx, ty = hy

      if (this.pointer) {
        const dx = this.pointer[0] - hx, dy = this.pointer[1] - hy
        const distance = Math.hypot(dx, dy)
        const force = Math.exp(-((distance / this.reachValue) ** 2))
        if (distance > 0.5) {
          tx = hx + (dx / distance) * this.pullValue * force
          ty = hy + (dy / distance) * this.pullValue * force
        }
      }

      node.at[0] += (tx - node.at[0]) * 0.16
      node.at[1] += (ty - node.at[1]) * 0.16
      if (Math.abs(tx - node.at[0]) > 0.08 || Math.abs(ty - node.at[1]) > 0.08) moving = true
    }

    this.draw()
    if (moving) this.start()
  }

  draw() {
    const pen = this.pen
    pen.clearRect(0, 0, window.innerWidth, window.innerHeight)
    pen.lineWidth = 1
    pen.lineJoin = "round"
    pen.strokeStyle = "rgba(26, 38, 54, 0.20)"

    for (const cell of this.cells) {
      pen.beginPath()
      cell.corners.forEach((corner, position) => {
        const [ x, y ] = this.nodes[corner].at
        position === 0 ? pen.moveTo(x, y) : pen.lineTo(x, y)
      })
      pen.closePath()
      if (cell.tint) {
        pen.fillStyle = cell.tint
        pen.fill()
      }
      pen.stroke()
    }
  }
}

// Mulberry32: small, seeded, and good enough to cut glass with.
function seeded(seed) {
  return function () {
    seed |= 0
    seed = seed + 0x6D2B79F5 | 0
    let t = Math.imul(seed ^ seed >>> 15, 1 | seed)
    t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t
    return ((t ^ t >>> 14) >>> 0) / 4294967296
  }
}
