import { Controller } from "@hotwired/stimulus"

// Writes a swatch's colour beside its name, read from the page's own computed
// styles rather than typed, so the specimen cannot say one thing while the
// stylesheet does another. The demo's own, not Janela's.
export default class extends Controller {
  static targets = ["value"]
  static values = { property: String }

  connect() {
    const probe = document.createElement("span")
    probe.style.color = getComputedStyle(this.element).getPropertyValue(this.propertyValue)
    document.body.appendChild(probe)
    const [ r, g, b ] = getComputedStyle(probe).color.match(/\d+/g).map(Number)
    probe.remove()
    this.valueTarget.textContent = `#${[ r, g, b ].map((each) => each.toString(16).padStart(2, "0")).join("")}`
  }
}
