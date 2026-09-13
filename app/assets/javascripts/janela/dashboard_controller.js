import { Controller } from "@hotwired/stimulus"

// Shared filter state for every visual on the page. Clicking a value rewrites
// each frame's src, and Turbo reloads a frame whenever its src changes -- so
// cross-filtering needs no streams, no sockets and no state library.
export default class extends Controller {
  static targets = ["visual"]
  static values = { filters: Object }

  toggle({ params: { key, value } }) {
    const filters = { ...this.filtersValue }

    if (filters[key] === String(value)) {
      delete filters[key]
    } else {
      filters[key] = String(value)
    }

    this.filtersValue = filters
  }

  clear() {
    this.filtersValue = {}
  }

  filtersValueChanged() {
    this.visualTargets.forEach((visual) => {
      const url = new URL(visual.dataset.janelaSrc, window.location.origin)

      for (const [key, value] of Object.entries(this.filtersValue)) {
        url.searchParams.set(`q[${key}]`, value)
      }

      if (visual.src !== url.href) visual.src = url.href
    })
  }
}
