import { Controller } from "@hotwired/stimulus"

// The renderer, granularity and limit a query answers are baked into its
// turbo frame id (Janela::Query.turbo_frame_id), so a response for a changed
// selection never carries the id the pane already has. Turbo's own frame
// navigation matches a response to a request by that id, or failing that by
// src, finds neither here, and leaves the frame exactly as it was: no error,
// no reload, a control that silently does nothing (investigated for #40).
// Fetching the new pane ourselves and updating the existing frame's id and
// content in one step sidesteps that matching, the same way visiting a fresh
// janela_pane call would, while keeping the element Janela's own frame
// controller already knows as a pane.
export default class extends Controller {
  static values = { model: String, measure: String, dimension: String }

  connect() {
    this.sequence = 0
    this.element.querySelector(".gallery-config-form").hidden = false
  }

  async change() {
    const frame = this.element.querySelector("turbo-frame")
    const url = this.urlFor(frame)
    const sequence = ++this.sequence

    const html = await fetch(url).then((response) => response.text())
    if (sequence !== this.sequence) return // a later change already answered this

    const fresh = new DOMParser().parseFromString(html, "text/html").querySelector("turbo-frame")
    if (!fresh) return

    frame.id = fresh.id
    frame.innerHTML = fresh.innerHTML
    // What this pane now shows, so a later cross-filter click compares
    // against the truth rather than the selection this replaced (#33's fix
    // for the frame controller applies here too: janelaAsked is the record of
    // what was actually asked for, not whatever the src attribute says).
    frame.dataset.janelaSrc = url.pathname + url.search
    frame.dataset.janelaAsked = frame.dataset.janelaSrc

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

  // The same shape entry.declaration builds server side, kept in step here
  // because only the browser knows what was just chosen.
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
