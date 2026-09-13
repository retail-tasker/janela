import "@hotwired/turbo-rails"
import { Application } from "@hotwired/stimulus"
import JanelaDashboardController from "janela/dashboard_controller"

const application = Application.start()
application.register("janela--dashboard", JanelaDashboardController)
