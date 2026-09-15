import { Controller } from "@hotwired/stimulus"
import { Chart, registerables } from "chart.js"

Chart.register(...registerables)

// Renders one pane as a chart and turns a click on a bar into the same
// toggle event a table button emits, so the dashboard controller cannot tell
// the difference. Turbo replaces the frame on every cross-filter, so the chart
// is destroyed on disconnect and rebuilt on connect.
export default class extends Controller {
  static values = { type: String, labels: Array, values: Array, key: String, title: String, selected: String }

  connect() {
    this.chart = new Chart(this.element, {
      type: this.typeValue,
      data: {
        labels: this.labelsValue,
        datasets: [{ label: this.titleValue, data: this.valuesValue, backgroundColor: this.colours() }]
      },
      options: {
        animation: false,
        plugins: { legend: { display: false } },
        onClick: (_event, elements) => {
          if (elements.length === 0) return
          const value = this.labelsValue[elements[0].index]
          this.dispatch("toggle", { detail: { key: this.keyValue, value } })
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
