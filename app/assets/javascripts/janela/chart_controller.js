import { Controller } from "@hotwired/stimulus"
import { Chart, registerables } from "chart.js"

Chart.register(...registerables)

// Renders one pane as a chart and turns a click on a bar into the same
// toggle event a table button emits, so the frame controller cannot tell the
// difference. Turbo replaces the turbo frame on every cross-filter, so the
// chart is destroyed on disconnect and rebuilt on connect.
export default class extends Controller {
  static values = { type: String, labels: Array, values: Array, filters: Object, title: String,
                    selected: String, formatted: Array }

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
        onClick: (_event, elements) => {
          if (elements.length === 0) return
          const label = this.labelsValue[elements[0].index]
          const [key, value] = this.filtersValue[String(label)] || []
          if (key) this.dispatch("toggle", { detail: { key, value } })
        }
      }
    })
  }

  // With nothing selected every bar is solid; with a selection only that bar is.
  colours() {
    const selected = this.selectedValue
    return this.labelsValue.map((label) =>
      !selected || label === selected ? "rgba(54, 162, 235, 0.9)" : "rgba(54, 162, 235, 0.25)"
    )
  }

  disconnect() {
    this.chart?.destroy()
    this.chart = null
  }
}
