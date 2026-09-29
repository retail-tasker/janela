import { Controller } from "@hotwired/stimulus"
import { Chart, registerables } from "chart.js"

Chart.register(...registerables)

// Renders one pane as a chart and turns a click on a bar into the same
// toggle event a table button emits, so the frame controller cannot tell the
// difference. Turbo replaces the turbo frame on every cross-filter, so the
// chart is destroyed on disconnect and rebuilt on connect.
export default class extends Controller {
  static values = { type: String, labels: Array, values: Array, filters: Object, title: String,
                    selected: Array, formatted: Array }

  connect() {
    this.chart = new Chart(this.element, {
      type: this.typeValue,
      data: {
        labels: this.labelsValue,
        datasets: [{
          label: this.titleValue,
          data: this.valuesValue,
          backgroundColor: this.colours(),
          borderColor: this.typeValue === "bar" ? this.colours(0.9) : this.accentColour(0.9),
          ...this.pointStyle()
        }]
      },
      options: {
        animation: false,
        scales: { y: { beginAtZero: true } },
        // A line is clicked anywhere along its x position rather than on
        // the exact pixel of a point, which on a dense series is a few
        // pixels wide (ADR 045).
        interaction: this.typeValue === "line" ? { mode: "nearest", axis: "x", intersect: false } : undefined,
        plugins: {
          legend: { display: false },
          // The server formatted every number for the table, so the tooltip
          // reads the same string rather than formatting a second time here
          // and disagreeing with the cell beside it.
          tooltip: { callbacks: { label: (item) => this.formattedValue[item.dataIndex] ?? item.formattedValue } }
        },
        onClick: (event, elements) => {
          if (elements.length === 0) return
          const label = this.labelsValue[elements[0].index]
          const entry = this.filtersValue[String(label)]
          // A custom event carries no modifier flags of its own, so the
          // gesture is read here and passed on (ADR 024).
          const additive = event.native?.ctrlKey === true || event.native?.metaKey === true
          // A category is one key and value. A time bucket is an object of
          // the conditions for its range, which is never additive (ADR 045).
          if (Array.isArray(entry) && entry[0]) {
            this.dispatch("toggle", { detail: { key: entry[0], value: entry[1], additive } })
          } else if (entry && !Array.isArray(entry)) {
            this.dispatch("toggle", { detail: { filters: entry } })
          }
        }
      }
    })
  }

  // With nothing selected every bar is solid; with a selection only the
  // selected ones are, and there can be more than one of them. A bar takes
  // the colour for its position in the palette (ADR 046); a line is one
  // series and keeps the accent.
  colours(unselected = 0.25) {
    const selected = this.selectedValue.map(String)
    return this.labelsValue.map((label, index) => {
      const solid = selected.length === 0 || selected.includes(String(label))
      const property = this.typeValue === "bar" ? this.seriesProperty(index) : "--janela-accent"
      return this.colour(property, solid ? 0.9 : unselected)
    })
  }

  // A line shows its selection on its points: the buckets inside the range
  // are solid and larger, the rest faded. A dense series draws no points
  // until one is hovered, so it stays a line (ADR 045).
  pointStyle() {
    if (this.typeValue !== "line") return {}

    const selected = this.selectedValue.map(String)
    const dense = this.labelsValue.length > 60
    return {
      pointBackgroundColor: this.colours(),
      pointBorderColor: this.colours(),
      pointRadius: this.labelsValue.map((label) => selected.includes(String(label)) ? 5 : (dense ? 0 : 3)),
      pointHoverRadius: 6
    }
  }

  // First to eighth, then the neutral. Never cycled: the ninth bar in the
  // first bar's colour would be two categories drawn the same (ADR 046).
  seriesProperty(index) {
    return index < 8 ? `--janela-series-${index + 1}` : "--janela-series-other"
  }

  accentColour(alpha) {
    return this.colour("--janela-accent", alpha)
  }

  // #62: this used to be a literal rgba(54, 162, 235, ...), Chart.js's own
  // default, so a bar disagreed with --janela-accent (ADR 016) and with
  // every other selected thing on the page. Read off this element rather
  // than the document root, so whatever ancestor sets the property is the
  // one honoured, the way it already inherits for everything else.
  colour(property, alpha) {
    const [ r, g, b ] = this.resolved(property).match(/\d+/g)
    return `rgba(${r}, ${g}, ${b}, ${alpha})`
  }

  // A custom property's computed value is returned exactly as authored,
  // "rgb(...)", "#7c3aed", a name, never resolved the way an ordinary
  // colour property is. Setting it as one and reading that back resolves
  // any of them the same way, rather than parsing each form by hand.
  resolved(property) {
    this.resolvedColours ||= {}
    if (this.resolvedColours[property]) return this.resolvedColours[property]

    const authored = getComputedStyle(this.element).getPropertyValue(property).trim()
    const probe = document.createElement("span")
    probe.style.color = authored
    document.body.appendChild(probe)
    this.resolvedColours[property] = getComputedStyle(probe).color
    probe.remove()
    return this.resolvedColours[property]
  }

  disconnect() {
    this.chart?.destroy()
    this.chart = null
  }
}
