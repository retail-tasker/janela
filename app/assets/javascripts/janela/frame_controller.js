import { Controller } from "@hotwired/stimulus"

// Shared filter state for every pane in the frame. Clicking a value rewrites
// each turbo frame's src, and Turbo reloads one whenever its src changes, so
// cross-filtering needs no streams, no sockets and no state library.
export default class extends Controller {
  static targets = ["pane"]
  static values = { filters: Object }

  // Table buttons send key/value as Stimulus action params; charts dispatch a
  // custom event carrying them in detail. Either way it is one value being
  // added to or taken out of a selection.
  //
  // A plain click selects that value alone, or clears the dimension if it was
  // the only one selected. Ctrl or Cmd adds and removes while the rest stay,
  // which is how every list in every operating system already behaves. The
  // same event carries the same flags when Enter is pressed on a focused
  // value, so the keyboard needs nothing of its own (ADR 024).
  toggle(event) {
    const { key, value } = { ...event.detail, ...event.params }
    const additive = event.ctrlKey || event.metaKey || event.detail?.additive === true
    const filters = { ...this.filtersValue }
    const selected = this.valuesFor(filters, key).includes(String(value))

    // The null group asks for rows that have nothing there, so it cannot be
    // combined with a value: Ransack ands its conditions, and the pair matches
    // no row at all. It is exclusive within its dimension instead.
    this.clearDimension(filters, key)

    if (key.endsWith("_null")) {
      if (!selected) filters[key] = "1"
    } else {
      let values = additive ? this.valuesFor(this.filtersValue, key) : []
      values = selected ? values.filter((each) => each !== String(value)) : [ ...values, String(value) ]
      if (values.length) filters[key] = [ ...new Set(values) ].sort()
    }

    this.filtersValue = filters
  }

  clear() {
    if (Object.keys(this.filtersValue).length) this.filtersValue = {}
  }

  // Whatever is selected for one key, as a set of strings. A filter arrives as
  // an array from a click and as a string from a hand written _eq link.
  valuesFor(filters, key) {
    const held = filters[key]
    if (held === undefined) return []

    return (Array.isArray(held) ? held : [ held ]).map(String)
  }

  // Every filter Janela itself writes for the same dimension: the values, the
  // null group, and an _eq that a shared link may still carry. A host's own
  // q[...] filters use other predicates and are left alone (ADR 008).
  clearDimension(filters, key) {
    const base = key.replace(/_(in|null|eq)$/, "")
    for (const suffix of [ "in", "null", "eq" ]) delete filters[`${base}_${suffix}`]
  }

  // Stimulus calls this as the controller connects, handing back the value it
  // just read from the attribute the server rendered, so nothing has changed
  // yet. A frame rendered from rows is already showing the right numbers
  // inline, and a src assigned here would make Turbo fetch every pane and
  // throw that first render away (ADR 014).
  filtersValueChanged(filters, previous) {
    if (previous === undefined || JSON.stringify(filters) === JSON.stringify(previous)) return

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

  // Sorted, keys and values both, so the browser serialises a selection the
  // same way every time and an unchanged src is never reloaded.
  writeFilters(url) {
    for (const key of Object.keys(this.filtersValue).sort()) {
      const held = this.filtersValue[key]
      if (Array.isArray(held)) {
        for (const value of [ ...held ].sort()) url.searchParams.append(`q[${key}][]`, value)
      } else {
        url.searchParams.set(`q[${key}]`, held)
      }
    }
  }
}
