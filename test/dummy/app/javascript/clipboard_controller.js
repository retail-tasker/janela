import { Controller } from "@hotwired/stimulus"

// Copies a line the visitor would otherwise select by hand. The demo's own,
// not Janela's: copying a Gemfile line is a marketing page's concern.
export default class extends Controller {
  static values = { text: String }
  static targets = ["button"]

  async copy() {
    try {
      await navigator.clipboard.writeText(this.textValue)
      this.say("Copied")
    } catch {
      this.say("Press ⌘C")
    }
  }

  say(message) {
    const button = this.hasButtonTarget ? this.buttonTarget : this.element
    const was = button.textContent
    button.textContent = message
    clearTimeout(this.timer)
    this.timer = setTimeout(() => { button.textContent = was }, 1600)
  }
}
