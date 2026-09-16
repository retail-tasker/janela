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
    pull: { type: Number, default: 26 },     // how far a node nearest the cursor travels
    overscan: { type: Number, default: 70 }, // how far past the window the glass is cut
    near: { type: Number, default: 0.16 },   // how much of a scroll the lead takes
    far: { type: Number, default: 0.06 }     // and the light behind it, which is further away
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
    this.onScroll = this.onScroll.bind(this)

    // Decoration waits its turn. Cutting the glass is a few hundred polygons,
    // and a dashboard's first paint and its frames matter more than a
    // background does, so the first draw happens once the browser is idle.
    this.idle = window.requestIdleCallback
      ? requestIdleCallback(() => this.cut(), { timeout: 600 })
      : setTimeout(() => this.cut(), 120)

    window.addEventListener("resize", this.onResize, { passive: true })
    if (!this.still) {
      window.addEventListener("scroll", this.onScroll, { passive: true })
      this.onScroll()
      window.addEventListener("pointermove", this.onMove, { passive: true })
      document.addEventListener("pointerleave", this.onLeave)
    }
  }

  disconnect() {
    window.removeEventListener("resize", this.onResize)
    window.removeEventListener("scroll", this.onScroll)
    window.removeEventListener("pointermove", this.onMove)
    document.removeEventListener("pointerleave", this.onLeave)
    cancelAnimationFrame(this.frame)
    cancelAnimationFrame(this.drifting)
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
    const page = document.documentElement.scrollHeight - window.innerHeight
    this.slack = this.still ? 0 : Math.min(600, Math.ceil(page * this.nearValue) + 20)

    const w = window.innerWidth
    const h = window.innerHeight + this.slack * 2
    this.canvas.width = Math.ceil(w * devicePixelRatio)
    this.canvas.height = Math.ceil(h * devicePixelRatio)
    this.canvas.style.width = `${w}px`
    this.canvas.style.height = `${h}px`
    this.canvas.style.top = `${-this.slack}px`
    this.canvas.style.bottom = "auto"
    this.pen.setTransform(devicePixelRatio, 0, 0, devicePixelRatio, 0, 0)
    this.paper = [ w, h ]

    const cols = this.columnsValue
    // Taller glass, same size cells, so the pattern does not stretch.
    const rows = Math.max(3, Math.round(this.rowsValue * h / window.innerHeight))

    // Cut wider than the window, and pin the outermost ring. A node that can
    // be dragged off the edge takes the glass with it and leaves a bare gap
    // there, so the outer ring is held and lives off screen besides. The
    // window flexes; its frame does not.
    const pad = this.overscanValue
    const cw = (w + pad * 2) / cols, ch = (h + pad * 2) / rows

    this.nodes = []
    const index = (r, c) => r * (cols + 1) + c
    for (let r = 0; r <= rows; r++) {
      for (let c = 0; c <= cols; c++) {
        const pinned = c === 0 || c === cols || r === 0 || r === rows
        const x = -pad + c * cw + (pinned ? 0 : (random() - 0.5) * 0.64 * cw)
        const y = -pad + r * ch + (pinned ? 0 : (random() - 0.5) * 0.64 * ch)
        this.nodes.push({ home: [ x, y ], at: [ x, y ], pinned })
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
            ? `rgba(${tints[Math.floor(random() * tints.length)]}, ${(0.025 + random() * 0.035).toFixed(3)})`
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

  // Both background layers move with the page, and neither keeps up with it.
  // What is near slides past, what is far barely shifts, which is what makes
  // the window read as a window rather than as wallpaper.
  onScroll() {
    if (this.drifting) return

    this.drifting = requestAnimationFrame(() => {
      this.drifting = null
      const scrolled = window.scrollY

      // Each layer is clamped to the slack it actually has, or it drifts past
      // its own edge and shows the bare ground behind it on a long page. The
      // lead's slack is how much taller than the window it was cut; the
      // light's is the 20vmax it hangs outside the window by.
      const lead = this.slack ?? 0
      const light = 0.2 * Math.max(window.innerWidth, window.innerHeight)

      this.element.style.setProperty("--vitral-drift-near", `${clamp(-scrolled * this.nearValue, lead)}px`)
      this.element.style.setProperty("--vitral-drift-far", `${clamp(-scrolled * this.farValue, light)}px`)

      // The glass has just slid under a cursor that has not moved, so the
      // nodes have to take aim again or they stay reaching for the place the
      // cursor used to be.
      if (this.aim) this.start()
    })
  }

  onMove(event) {
    // Kept in screen coordinates and converted when the frame is drawn. The
    // glass is cut taller than the window and drifts as the page scrolls, so
    // where the cursor is on screen is not where it is on the canvas, and
    // converting here would mean reading layout on every pointer event.
    this.aim = [ event.clientX, event.clientY ]
    this.element.style.setProperty("--vitral-shift-x", (event.clientX / window.innerWidth - 0.5).toFixed(3))
    this.element.style.setProperty("--vitral-shift-y", (event.clientY / window.innerHeight - 0.5).toFixed(3))
    this.start()
  }

  onLeave() {
    this.aim = null
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

    // One layout read per frame rather than one per pointer event. The rect
    // accounts for the overscan, the scroll drift and the pointer parallax in
    // a single measurement, so the pull lands where the cursor actually is.
    const pointer = this.aimOnGlass()
    let moving = false

    for (const node of this.nodes) {
      const [ hx, hy ] = node.home
      let tx = hx, ty = hy

      if (pointer && !node.pinned) {
        const dx = pointer[0] - hx, dy = pointer[1] - hy
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

  aimOnGlass() {
    if (!this.aim) return null

    const rect = this.canvas.getBoundingClientRect()
    return [ this.aim[0] - rect.left, this.aim[1] - rect.top ]
  }

  draw() {
    const pen = this.pen
    pen.clearRect(0, 0, this.paper[0], this.paper[1])
    pen.lineWidth = 1
    pen.lineJoin = "round"
    // The stylesheet owns the colour, so a retheme is one property and the
    // live lattice never disagrees with the static one.
    pen.strokeStyle = this.ink ||= getComputedStyle(this.element)
      .getPropertyValue("--vitral-lattice-ink").trim() || "rgba(44, 62, 84, 0.11)"

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

function clamp(value, limit) {
  return Math.max(-limit, Math.min(limit, value)).toFixed(1)
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
