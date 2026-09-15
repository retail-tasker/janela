import { Controller } from "@hotwired/stimulus"

// Shared filter state for every pane in the frame. Clicking a value rewrites
// each turbo frame's src, and Turbo reloads one whenever its src changes, so
// cross-filtering needs no streams, no sockets and no state library.
export default class extends Controller {
  static targets = ["pane"]
  static values = { filters: Object }

  // Table buttons send key/value as Stimulus action params; charts dispatch a
  // custom event carrying them in detail. Either way it is one filter toggle.
  toggle(event) {
    const { key, value } = { ...event.detail, ...event.params }
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
    this.paneTargets.forEach((pane) => {
      const url = new URL(pane.dataset.janelaSrc, window.location.origin)
      this.writeFilters(url)
      if (pane.src !== url.href) pane.src = url.href
    })

    this.syncPageUrl()
  }

  // The page URL carries the same q[...] the panes do, so a reload or a
  // pasted link opens the frame filtered (ADR 008). Replaced rather than
  // pushed: a click is not a place the back button should return to.
  syncPageUrl() {
    const url = new URL(window.location.href)
    for (const key of [...url.searchParams.keys()]) {
      if (key.startsWith("q[")) url.searchParams.delete(key)
    }
    this.writeFilters(url)
    if (url.href !== window.location.href) history.replaceState(history.state, "", url)
  }

  // Sorted so the browser serialises filters the same way the server does and
  // an unchanged src is never reloaded.
  writeFilters(url) {
    for (const key of Object.keys(this.filtersValue).sort()) {
      url.searchParams.set(`q[${key}]`, this.filtersValue[key])
    }
  }
}
