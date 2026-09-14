pin "janela/dashboard_controller", to: "janela/dashboard_controller.js"
pin "janela/chart_controller", to: "janela/chart_controller.js"

# Hosts that already pin their own Chart.js keep it.
pin "chart.js", to: "janela/vendor/chart.js" unless packages.key?("chart.js")
