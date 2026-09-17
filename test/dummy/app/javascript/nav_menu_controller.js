import { Controller } from "@hotwired/stimulus"

// A cached back/forward visit restores the previous document instantly, open
// attribute and all: no fetch happens, so nothing else gives the menu a
// chance to start closed again. turbo:before-cache fires on the document
// that is about to be stored, which is the one moment to close it before
// that snapshot becomes what a later back visit hands back.
export default class extends Controller {
  connect() {
    document.addEventListener("turbo:before-cache", this.close)
  }

  disconnect() {
    document.removeEventListener("turbo:before-cache", this.close)
  }

  close = () => {
    this.element.removeAttribute("open")
  }
}
