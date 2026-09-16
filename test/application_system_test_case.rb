require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]

  # A dashboard is not ready for a click until two things are true, and a test
  # that clicks sooner is testing its own timing rather than Janela.
  #
  # The frame controller has to have connected, or a click does nothing.
  #
  # And every pane with a src has to have finished its first load. A pane's
  # table is replaced when that load lands, so a click on a button a moment
  # before goes to an element that is no longer in the page, and nothing
  # hears it. Numbers rendered on the server are on the page before either is
  # true, which is why waiting for them proved nothing.
  def visit(...)
    super
    wait_for_frames
  end

  private
    def wait_for_frames(timeout: Capybara.default_max_wait_time * 2)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
      loop do
        ready = page.evaluate_script(<<~JS)
          (() => {
            const frames = [...document.querySelectorAll("[data-controller~='janela--frame']")]
            if (frames.length === 0) return true
            if (!window.Stimulus) return false
            const connected = frames.every((el) => window.Stimulus.getControllerForElementAndIdentifier(el, "janela--frame"))
            const loaded = [...document.querySelectorAll("turbo-frame[src]")]
              .every((pane) => pane.hasAttribute("complete") && !pane.hasAttribute("busy"))
            return connected && loaded
          })()
        JS
        return if ready
        raise "the dashboard never became ready for a click" if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

        sleep 0.05
      end
    end
end
