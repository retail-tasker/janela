import { Controller } from "@hotwired/stimulus"

// Repointing a pane is the frame controller's job rather than this control's:
// it is the only thing that knows what the frame is filtered to, and the
// gallery cross-filters like any other page of panes, so a pane repointed
// without those filters would show numbers for a filter state nobody is in
// beside panes that are still filtered (ADR 030). This builds the query that
// was chosen, from the pane's own path and nothing else, and asks the frame
// for it. Turbo does the rest: fetch, reconcile, redraw, chart controller
// included.
export default class extends Controller {
  static values = { model: String, measure: String, dimension: String, path: String, maxCompanions: Number }

  connect() {
    this.element.querySelector(".gallery-config-form").hidden = false
    this.refresh()
  }

  change() {
    this.refresh()
    this.element.querySelector("turbo-frame").dispatchEvent(
      new CustomEvent("janela--frame:repoint", { bubbles: true, detail: { url: this.url() } })
    )

    // The same shape entry.declaration builds server side, kept in step here
    // because only the browser knows what was just chosen.
    this.element.querySelector(".gallery-declaration").textContent = this.declaration()
  }

  // Each option is offered only while the renderer chosen is one it changes
  // (data-renderers), and the third companion is the last: the pane refuses a
  // fourth, so the control stops offering one rather than letting a reader draw
  // an error.
  refresh() {
    this.element.querySelectorAll("[data-renderers]").forEach((field) => {
      field.hidden = !field.dataset.renderers.split(" ").includes(this.renderer)
    })

    const boxes = [ ...this.element.querySelectorAll("[name='companions[]']") ]
    const full = boxes.filter((box) => box.checked).length >= this.maxCompanionsValue
    boxes.forEach((box) => { box.disabled = full && !box.checked })
  }

  url() {
    const url = new URL(this.pathValue, window.location.origin)
    if (this.renderer !== "table") url.searchParams.set("as", this.renderer)
    if (this.granularity) url.searchParams.set("granularity", this.granularity)
    if (this.limit) url.searchParams.set("limit", this.limit)
    if (this.height) url.searchParams.set("height", this.height)
    if (this.valueLabels) url.searchParams.set("value_labels", "1")
    if (this.prominence) url.searchParams.set("prominence", this.prominence)
    this.companions.forEach((name) => url.searchParams.append("companions[]", name))

    return url.href
  }

  declaration() {
    const parts = [ `janela_pane ${this.modelValue}, :${this.measureValue}` ]
    if (this.dimensionValue) parts.push(`by: :${this.dimensionValue}`)
    if (this.renderer !== "table") parts.push(`as: :${this.renderer}`)
    if (this.granularity) parts.push(`granularity: :${this.granularity}`)
    if (this.limit) parts.push(`limit: ${this.limit}`)
    if (this.height) parts.push(`height: ${this.height}`)
    if (this.valueLabels) parts.push("value_labels: true")
    if (this.prominence) parts.push(`prominence: ${this.prominence}`)
    if (this.companions.length) parts.push(`companions: [${this.companions.map((name) => `:${name}`).join(", ")}]`)
    return parts.join(", ")
  }

  // A single value has no renderer to choose, and is drawn as itself.
  get renderer() {
    return this.element.querySelector("[name=renderer]")?.value ?? "table"
  }

  get granularity() {
    return this.element.querySelector("[name=granularity]")?.value
  }

  get limit() {
    return this.element.querySelector("[name=limit]")?.value
  }

  // An option the renderer ignores is left out of the URL and the declaration:
  // a copied line should not read as if it did something it does not.
  get height() {
    return this.shown("height")?.value
  }

  get prominence() {
    return this.shown("prominence")?.value
  }

  get valueLabels() {
    return this.shown("value_labels")?.checked
  }

  get companions() {
    return [ ...this.element.querySelectorAll("[name='companions[]']:checked") ].filter((box) => !box.closest("[hidden]")).map((box) => box.value)
  }

  shown(name) {
    const field = this.element.querySelector(`[name='${name}']`)
    return field && !field.closest("[hidden]") ? field : null
  }
}
