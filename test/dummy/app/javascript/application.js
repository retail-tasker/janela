import "@hotwired/turbo-rails"
import { Application } from "@hotwired/stimulus"
import JanelaDashboardController from "janela/dashboard_controller"
import JanelaChartController from "janela/chart_controller"

const application = Application.start()
application.register("janela--dashboard", JanelaDashboardController)
application.register("janela--chart", JanelaChartController)

window.Stimulus = application
