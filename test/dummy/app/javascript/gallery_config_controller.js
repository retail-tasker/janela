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
  static values = { model: String, measure: String, dimension: String, path: String }

  connect() {
    this.element.querySelector(".gallery-config-form").hidden = false
  }

  change() {
    this.element.querySelector("turbo-frame").dispatchEvent(
      new CustomEvent("janela--frame:repoint", { bubbles: true, detail: { url: this.url() } })
    )

    // The same shape entry.declaration builds server side, kept in step here
    // because only the browser knows what was just chosen.
    this.element.querySelector(".gallery-declaration").textContent = this.declaration()
  }

  url() {
    const url = new URL(this.pathValue, window.location.origin)
    if (this.renderer !== "table") url.searchParams.set("as", this.renderer)
    if (this.granularity) url.searchParams.set("granularity", this.granularity)
    if (this.limit) url.searchParams.set("limit", this.limit)

    return url.href
  }

  declaration() {
    const parts = [ `janela_pane ${this.modelValue}, :${this.measureValue}` ]
    if (this.dimensionValue) parts.push(`by: :${this.dimensionValue}`)
    if (this.renderer !== "table") parts.push(`as: :${this.renderer}`)
    if (this.granularity) parts.push(`granularity: :${this.granularity}`)
    if (this.limit) parts.push(`limit: ${this.limit}`)
    return parts.join(", ")
  }

  get renderer() {
    return this.element.querySelector("[name=renderer]").value
  }

  get granularity() {
    return this.element.querySelector("[name=granularity]")?.value
  }

  get limit() {
    return this.element.querySelector("[name=limit]")?.value
  }
}
