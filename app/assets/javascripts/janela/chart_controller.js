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
          borderColor: this.accentColour(0.9)
        }]
      },
      options: {
        animation: false,
        scales: { y: { beginAtZero: true } },
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
          const [key, value] = this.filtersValue[String(label)] || []
          // A custom event carries no modifier flags of its own, so the
          // gesture is read here and passed on (ADR 024).
          const additive = event.native?.ctrlKey === true || event.native?.metaKey === true
          if (key) this.dispatch("toggle", { detail: { key, value, additive } })
        }
      }
    })
  }

  // With nothing selected every bar is solid; with a selection only the
  // selected ones are, and there can be more than one of them.
  colours() {
    const selected = this.selectedValue.map(String)
    return this.labelsValue.map((label) =>
      selected.length === 0 || selected.includes(String(label))
        ? this.accentColour(0.9)
        : this.accentColour(0.25)
    )
  }

  // #62: this used to be a literal rgba(54, 162, 235, ...), Chart.js's own
  // default, so a bar disagreed with --janela-accent (ADR 016) and with
  // every other selected thing on the page. Read off this element rather
  // than the document root, so whatever ancestor sets the property is the
  // one honoured, the way it already inherits for everything else.
  accentColour(alpha) {
    const [ r, g, b ] = this.resolvedAccent().match(/\d+/g)
    return `rgba(${r}, ${g}, ${b}, ${alpha})`
  }

  // A custom property's computed value is returned exactly as authored,
  // "rgb(...)", "#7c3aed", a name, never resolved the way an ordinary
  // colour property is. Setting it as one and reading that back resolves
  // any of them the same way, rather than parsing each form by hand.
  resolvedAccent() {
    if (this.resolvedAccentValue) return this.resolvedAccentValue

    const accent = getComputedStyle(this.element).getPropertyValue("--janela-accent").trim()
    const probe = document.createElement("span")
    probe.style.color = accent
    document.body.appendChild(probe)
    this.resolvedAccentValue = getComputedStyle(probe).color
    probe.remove()
    return this.resolvedAccentValue
  }

  disconnect() {
    this.chart?.destroy()
    this.chart = null
  }
}
