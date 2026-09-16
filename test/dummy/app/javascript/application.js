import "@hotwired/turbo-rails"
import { Application } from "@hotwired/stimulus"
import JanelaFrameController from "janela/frame_controller"
import JanelaChartController from "janela/chart_controller"
import VitralController from "janela/vitral_controller"
import ClipboardController from "clipboard_controller"
import FanController from "fan_controller"

const application = Application.start()
application.register("janela--frame", JanelaFrameController)
application.register("janela--chart", JanelaChartController)
application.register("vitral", VitralController)
application.register("clipboard", ClipboardController)
application.register("fan", FanController)

window.Stimulus = application
