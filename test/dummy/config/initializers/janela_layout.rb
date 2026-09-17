# The dummy stands in for a host that wants its own pages, including Janela's,
# to look like one site (ADR 011, ADR 022). A host's route helpers now resolve
# inside the engine, so the condition ADR 011 attached to this override no
# longer applies. The turbo frame guard stays: a pane fetched into a frame
# still gets no layout, or it comes back wrapped in the whole page and Turbo
# has nothing to extract.
#
# to_prepare, not a bare assignment: it runs once autoloading can resolve
# Janela::ApplicationController, and again on every reload in development, so
# an edit to this file or the controller is picked up without a restart.
Rails.application.config.to_prepare do
  Janela::FramesController.layout -> { turbo_frame_request? ? false : "application" }
end
