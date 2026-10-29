import { Controller } from "@hotwired/stimulus"
import { Chart, Ticks, registerables } from "chart.js"

Chart.register(...registerables)

// Renders one pane as a chart and turns a click on a bar into the same
// toggle event a table button emits, so the frame controller cannot tell the
// difference. Turbo replaces the turbo frame on every cross-filter, so the
// chart is destroyed on disconnect and rebuilt on connect.
//
// labels, values and formatted are the pane's own series. A time pane may
// carry further series, each a dataset of its own on the left axis or a
// right one, and then the chart has a legend and both axes are titled
// (ADR 062). Without them nothing here is different from before.
export default class extends Controller {
  static values = { type: String, labels: Array, values: Array, filters: Object, title: String,
                    selected: Array, formatted: Array, tickFormat: Object, fixedHeight: Boolean, valueLabels: Boolean,
                    label: String, series: Array, axes: Object }

  connect() {
    const controller = this
    this.chart = new Chart(this.element, {
      type: this.typeValue,
      // A plugin cannot be added to a chart once it is built, so it is handed
      // over here, as the aspect ratio is for a height (ADR 047, ADR 054).
      plugins: this.valueLabelsValue ? [ { id: "janelaValueLabels", afterDatasetsDraw: (chart) => this.drawValueLabels(chart) } ] : [],
      data: {
        labels: this.labelsValue,
        datasets: [ this.primaryDataset(), ...this.seriesValue.map((series, index) => this.seriesDataset(series, index + 1)) ]
      },
      options: {
        animation: false,
        // A pane with a height is drawn into a box of that height, and the
        // aspect ratio has to be off for the chart to fill it (ADR 047). It
        // is decided here, when the chart is made: patched onto a chart built
        // with it on, it draws at the wrong size.
        maintainAspectRatio: !this.fixedHeightValue,
        scales: this.scales(),
        // A line is clicked anywhere along its x position rather than on
        // the exact pixel of a point, which on a dense series is a few
        // pixels wide (ADR 045). With several series a bucket is read across
        // all of them at once.
        interaction: this.interaction(),
        plugins: {
          legend: { display: this.hasSeries() },
          // The server formatted every number for the table, so the tooltip
          // reads the same string rather than formatting a second time here
          // and disagreeing with the cell beside it.
          tooltip: { callbacks: { label: (item) => this.formattedFor(item.datasetIndex)[item.dataIndex] ?? item.formattedValue } }
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

  hasSeries() {
    return this.seriesValue.length > 0
  }

  // The pane's own series. Alone it is what it always was: bars coloured by
  // position and a line in the accent. Beside further series it is the first
  // colour of the palette, and the others follow in order (ADR 062).
  primaryDataset() {
    const property = this.hasSeries() ? this.seriesProperty(0) : null
    return {
      label: this.hasSeries() ? this.labelValue : this.titleValue,
      data: this.valuesValue,
      type: this.typeValue,
      yAxisID: "y",
      order: this.typeValue === "bar" ? 2 : 1,
      backgroundColor: this.colours(0.25, property, this.typeValue === "bar" && property ? 0.55 : 0.9),
      borderColor: this.typeValue === "bar" ? this.colours(0.9, property, property ? 0.55 : 0.9) : (property ? this.colour(property, 0.9) : this.accentColour(0.9)),
      ...this.pointStyle(this.typeValue, property)
    }
  }

  // Bars are drawn behind lines and quieter than them, so a line stays the
  // story over the bars under it.
  seriesDataset(series, position) {
    const property = this.seriesProperty(position)
    return {
      label: series.label,
      data: series.values,
      type: series.type,
      yAxisID: series.axis === "right" ? "y1" : "y",
      order: series.type === "bar" ? 2 : 1,
      backgroundColor: series.type === "bar" ? this.colours(0.2, property, 0.55) : this.colours(0.25, property),
      borderColor: series.type === "bar" ? this.colours(0.2, property, 0.55) : this.colour(property, 0.9),
      ...this.pointStyle(series.type, property)
    }
  }

  formattedFor(datasetIndex) {
    return datasetIndex === 0 ? this.formattedValue : (this.seriesValue[datasetIndex - 1]?.formatted ?? [])
  }

  interaction() {
    if (this.hasSeries()) return { mode: "index", intersect: false }
    return this.typeValue === "line" ? { mode: "nearest", axis: "x", intersect: false } : undefined
  }

  // Chart.js picks the ticks, so the server cannot format them; each is
  // formatted here with what the measure declares (ADR 054). A right axis
  // exists only when a series asks for it, draws no grid across the plot,
  // and both axes are then titled with the series on them. When every series
  // on the right is bars, that axis is scaled so the tallest bar reaches
  // about a third of the plot, so bars sit under the lines (ADR 062).
  scales() {
    const controller = this
    const ticks = { callback(value, index, ticks) { return controller.tickLabel(this, value, index, ticks) } }
    const scales = { y: {
      beginAtZero: true,
      // Room above the tallest bar, and below the lowest, for its label (ADR 054).
      grace: this.valueLabelsValue ? "10%" : undefined,
      title: this.axisTitle(this.axesValue.left),
      ticks
    } }

    const right = this.seriesValue.filter((series) => series.axis === "right")
    if (right.length > 0) {
      const barsOnly = right.every((series) => series.type === "bar")
      const tallest = Math.max(0, ...right.flatMap((series) => series.values))
      scales.y1 = {
        position: "right",
        beginAtZero: true,
        suggestedMax: barsOnly && tallest > 0 ? tallest * 3 : undefined,
        grid: { drawOnChartArea: false },
        title: this.axisTitle(this.axesValue.right),
        ticks
      }
    }
    return scales
  }

  axisTitle(text) {
    return text ? { display: true, text } : undefined
  }

  // With value labels asked for: on a lone bar chart the same string the
  // tooltip shows at the end of each bar, above a positive one and below a
  // negative, all of them or none, since a label wider than its bar's slot
  // would overlap its neighbour and hiding only the ones that collide would
  // label some bars for a reason a reader cannot see (ADR 054). On a line its
  // latest value, once, at the end of the line, which is what a running total
  // wants (ADR 062). Bars beside other series draw none: their slots are
  // shared, and all or none would almost always say none.
  drawValueLabels(chart) {
    const { ctx } = chart
    const { size, family } = Chart.defaults.font
    ctx.save()
    ctx.font = `${size}px ${family}`
    ctx.fillStyle = Chart.defaults.color

    chart.data.datasets.forEach((dataset, index) => {
      const formatted = this.formattedFor(index)
      const points = chart.getDatasetMeta(index).data
      if (dataset.type === "line") {
        const last = points.at(-1)
        if (!last || formatted.length === 0) return
        ctx.textAlign = "right"
        ctx.textBaseline = "bottom"
        ctx.fillText(formatted.at(-1), last.x, last.y - 6)
      } else if (!this.hasSeries()) {
        this.drawBarLabels(chart, points, dataset.data, formatted)
      }
    })
    ctx.restore()
  }

  drawBarLabels(chart, bars, values, formatted) {
    const { ctx } = chart
    const slot = chart.chartArea.width / bars.length
    if (formatted.some((text) => ctx.measureText(text).width > slot)) return

    ctx.textAlign = "center"
    bars.forEach((bar, index) => {
      const negative = values[index] < 0
      ctx.textBaseline = negative ? "top" : "bottom"
      ctx.fillText(formatted[index], bar.x, negative ? bar.y + 4 : bar.y - 4)
    })
  }

  // Chart.js's own numeric formatter, so the decimals follow the spacing
  // between ticks: 20%, 40%, and 0.5%, 1% only where the ticks really are half
  // a percent apart. A ratio is stored as a fraction and read as a percentage
  // (ADR 038), so its ticks are scaled by 100, rounded first because 0.035 * 100
  // is 3.5000000000000004. The measure's precision is not used: it says what one
  // value means, and would print 20.0% at every tick.
  tickLabel(scale, value, index, ticks) {
    const { prefix = "", suffix = "", ratio = false } = this.tickFormatValue
    const factor = ratio ? 100 : 1
    const scaled = (number) => Number((number * factor).toPrecision(12))
    const number = Ticks.formatters.numeric.call(scale, scaled(value), index, ticks.map((tick) => ({ ...tick, value: scaled(tick.value) })))
    return `${prefix}${number}${ratio ? "%" : suffix}`
  }

  // With nothing selected every bar is solid; with a selection only the
  // selected ones are, and there can be more than one of them. A bar takes
  // the colour for its position in the palette (ADR 046); a line is one
  // series and keeps the accent. A dataset beside other series is given its
  // own property instead and every bucket takes that one colour, and a bar
  // there is quieter than a line (ADR 062).
  colours(unselected = 0.25, property = null, solidAlpha = 0.9) {
    const selected = this.selectedValue.map(String)
    return this.labelsValue.map((label, index) => {
      const solid = selected.length === 0 || selected.includes(String(label))
      const chosen = property || (this.typeValue === "bar" ? this.seriesProperty(index) : "--janela-accent")
      return this.colour(chosen, solid ? solidAlpha : unselected)
    })
  }

  // A line shows its selection on its points: the buckets inside the range
  // are solid and larger, the rest faded. A dense series draws no points
  // until one is hovered, so it stays a line (ADR 045).
  pointStyle(type = this.typeValue, property = null) {
    if (type !== "line") return {}

    const selected = this.selectedValue.map(String)
    const dense = this.labelsValue.length > 60
    return {
      pointBackgroundColor: this.colours(0.25, property),
      pointBorderColor: this.colours(0.25, property),
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
