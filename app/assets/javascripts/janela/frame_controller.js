import { Controller } from "@hotwired/stimulus"

// Shared filter state for every pane in the frame. Clicking a value rewrites
// each turbo frame's src, and Turbo reloads one whenever its src changes, so
// cross-filtering needs no streams, no sockets and no state library.
export default class extends Controller {
  static targets = ["pane"]
  static values = { filters: Object }

  initialize() {
    this.supersede = this.supersede.bind(this)
  }

  // A pane is a turbo frame that outlives its own contents, so the listener is
  // attached once per frame rather than once per render.
  paneTargetConnected(pane) {
    pane.addEventListener("turbo:before-fetch-request", this.supersede)
    // What the server already rendered this pane for is what Janela has asked
    // for, so a later change is measured against it rather than against
    // nothing.
    pane.dataset.janelaAsked ||= this.urlFor(pane).href
  }

  paneTargetDisconnected(pane) {
    pane.removeEventListener("turbo:before-fetch-request", this.supersede)
    pane.janelaRequest?.abort()
  }

  // The request for what Janela last asked for wins, and any other is
  // cancelled before it can land. A pane's load can be in flight when a click
  // asks it for something else, and Turbo renders whatever arrives, so an
  // older answer could overwrite a newer one and leave the pane showing
  // numbers for filters nobody has any more. Neither arrival order nor start
  // order settles it: a lazy load can begin after a click and still be for the
  // old address. What was asked for is the only honest rule (#33).
  supersede(event) {
    const pane = event.currentTarget
    const options = event.detail?.fetchOptions
    const url = event.detail?.url
    if (!options || !url) return

    const request = new AbortController()
    options.signal?.addEventListener("abort", () => request.abort(), { once: true })
    options.signal = request.signal

    const asked = pane.dataset.janelaAsked
    if (asked && new URL(url, window.location.origin).href !== asked) {
      // Stale before it started. Cancel it, and make sure the pane still ends
      // up fetching what was asked for, since this may have been its only load.
      request.abort()
      // Bounded, so an address spelled differently from the one Janela built
      // cannot set a pane correcting itself forever.
      const corrections = pane.janelaCorrectedFor === asked ? (pane.janelaCorrections || 0) : 0
      if ((!pane.janelaRequest || pane.janelaRequestFor !== asked) && corrections < 2) {
        pane.janelaCorrectedFor = asked
        pane.janelaCorrections = corrections + 1
        queueMicrotask(() => { pane.src === asked ? pane.reload() : (pane.src = asked) })
      }
      return
    }

    pane.janelaRequest?.abort()
    pane.janelaRequest = request
    pane.janelaRequestFor = asked
    request.signal.addEventListener("abort", () => {
      if (pane.janelaRequest === request) pane.janelaRequest = null
    }, { once: true })
  }

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

  // A host changes what a pane shows by asking here, and never by writing
  // src or one of the dataset records below. Turbo writes src back onto a
  // frame when a response lands, so src does not say what was asked for and
  // this controller keeps its own record instead (#33); a host writing that
  // record by hand has to write two attributes in the right order and
  // reapply the frame's filters itself, and only this controller knows what
  // those filters are. Getting it wrong is silent: the pane shows numbers
  // for a filter state nobody is in, beside panes that are still filtered
  // (ADR 003, ADR 030, #43).
  //
  // Dispatched on the pane, or on anything inside it, with the query to go
  // to. Filters are the frame's, so a caller says nothing about them:
  //
  //   pane.dispatchEvent(new CustomEvent("janela--frame:repoint",
  //     { bubbles: true, detail: { url: "/dashboards/orders/revenue/status?limit=5" } }))
  repoint(event) {
    const pane = this.paneTargets.find((each) => each.contains(event.target))
    const query = new URL(event.detail.url, window.location.origin)
    this.stripFilters(query)

    // The query without filters first, since it is what this pane's URL is
    // rebuilt from on the next click as well as on the line below.
    pane.dataset.janelaSrc = query.pathname + query.search
    const url = this.urlFor(pane)
    pane.dataset.janelaAsked = url.href
    pane.src = url.href
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

  // Stimulus calls this as the controller starts, with the filters the server
  // rendered, so nothing has changed yet. A frame is already showing the right
  // numbers, and a src assigned here would make Turbo fetch every pane and
  // throw that first render away (ADR 014).
  //
  // Janela keeps its own record of what it last applied rather than trusting
  // the previous value it is handed. On a page opened from a filtered link,
  // Stimulus passes the default empty object as the previous value, not
  // nothing, so a check on that alone reloaded every pane on connect, and the
  // redundant load could land after a click and undo it (#33).
  filtersValueChanged(filters) {
    const applied = JSON.stringify(filters)
    if (this.applied === undefined || this.applied === applied) {
      this.applied = applied
      return
    }
    this.applied = applied

    this.paneTargets.forEach((pane) => {
      const url = this.urlFor(pane)

      // Janela's own record of what it last asked this pane for, rather than
      // the pane's src. A lazy load that began before a click lands after it,
      // and Turbo then puts the URL it fetched back on the frame while leaving
      // the newer content in place, so src stops describing what is on screen.
      // Reading it meant the next change that happened to match was skipped
      // and the pane kept numbers nobody had asked for (#33).
      if (pane.dataset.janelaAsked === url.href) return

      pane.dataset.janelaAsked = url.href
      pane.src = url.href
    })

    this.syncPageUrl()
  }

  // The page URL carries the same q[...] the panes do, so a reload or a
  // pasted link opens the frame filtered (ADR 008). Replaced rather than
  // pushed: a click is not a place the back button should return to.
  syncPageUrl() {
    const url = new URL(window.location.href)
    this.stripFilters(url)
    this.writeFilters(url)
    if (url.href !== window.location.href) history.replaceState(history.state, "", url)
  }

  urlFor(pane) {
    const url = new URL(pane.dataset.janelaSrc, window.location.origin)
    this.writeFilters(url)
    return url
  }

  // The filters on a URL are Janela's to write, so whatever is already there
  // comes off before the current selection goes on: a page URL carrying the
  // filters a page was opened with, or a query a host handed to repoint.
  stripFilters(url) {
    for (const key of [ ...url.searchParams.keys() ]) {
      if (key.startsWith("q[")) url.searchParams.delete(key)
    }
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
