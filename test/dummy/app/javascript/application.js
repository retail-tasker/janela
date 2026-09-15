import "@hotwired/turbo-rails"
import { Application } from "@hotwired/stimulus"
import JanelaFrameController from "janela/frame_controller"
import JanelaChartController from "janela/chart_controller"

const application = Application.start()
application.register("janela--frame", JanelaFrameController)
application.register("janela--chart", JanelaChartController)

window.Stimulus = application
