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
          borderColor: "rgba(54, 162, 235, 0.9)"
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
        ? "rgba(54, 162, 235, 0.9)"
        : "rgba(54, 162, 235, 0.25)"
    )
  }

  disconnect() {
    this.chart?.destroy()
    this.chart = null
  }
}
