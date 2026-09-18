import { Controller } from "@hotwired/stimulus"

// A named pane's frame keeps one stable id no matter what its query changes
// to, and the response now answers to whatever frame asked for it rather
// than fingerprinting itself again from the query (ADR 029), so reconfiguring
// one is a plain navigation. Janela's own frame controller keeps a record of
// what it last asked each pane for and reverts any fetch that does not match
// it (#33), so that record is updated first, then the frame is pointed at
// the new URL and Turbo does the rest: fetch, reconcile, redraw, chart
// controller included.
export default class extends Controller {
  static values = { model: String, measure: String, dimension: String }

  connect() {
    this.element.querySelector(".gallery-config-form").hidden = false
  }

  change() {
    const frame = this.element.querySelector("turbo-frame")
    const url = this.urlFor(frame)

    frame.dataset.janelaSrc = url.pathname + url.search
    frame.dataset.janelaAsked = url.href
    frame.src = url.pathname + url.search

    // The same shape entry.declaration builds server side, kept in step here
    // because only the browser knows what was just chosen.
    this.element.querySelector(".gallery-declaration").textContent = this.declaration()
  }

  urlFor(frame) {
    const url = new URL(frame.dataset.janelaSrc, window.location.origin)
    url.searchParams.delete("as")
    url.searchParams.delete("granularity")
    url.searchParams.delete("limit")

    if (this.renderer !== "table") url.searchParams.set("as", this.renderer)
    if (this.granularity) url.searchParams.set("granularity", this.granularity)
    if (this.limit) url.searchParams.set("limit", this.limit)

    return url
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
