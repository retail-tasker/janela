import { Controller } from "@hotwired/stimulus"

// A "Clear filters" button for the front page, shown only while something is
// selected. Janela ships the action (janela--frame#clear) and binds Escape to
// it, and leaves a button to the host's own markup, so this is the demo's: it
// asks the frame's controller to clear rather than reaching into its state,
// and watches the attribute that controller writes its filters to.
export default class extends Controller {
  connect() {
    this.frame = document.querySelector("[data-controller~='janela--frame']")
    if (!this.frame) return

    this.observer = new MutationObserver(() => this.sync())
    this.observer.observe(this.frame, { attributes: true, attributeFilter: [ "data-janela--frame-filters-value" ] })
    this.sync()
  }

  disconnect() {
    this.observer?.disconnect()
  }

  clear() {
    this.application.getControllerForElementAndIdentifier(this.frame, "janela--frame")?.clear()
  }

  sync() {
    const filters = JSON.parse(this.frame.getAttribute("data-janela--frame-filters-value") || "{}")
    this.element.hidden = Object.keys(filters).length === 0
  }
}
