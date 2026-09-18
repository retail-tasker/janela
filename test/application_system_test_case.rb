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
    scroll_through_page
    wait_for_frames
  end

  private
    # A lazily loaded pane only fetches once the browser's own
    # IntersectionObserver has seen it, and neither Capybara nor a real
    # visitor scrolls a page just to make it finish loading. The gallery
    # became taller than the test viewport once a pane grew controls beside
    # it (#40), so its last pane sat below the fold, never intersected,
    # never fetched, and wait_for_frames waited for it forever. Walking the
    # page the way a visitor's own scrolling would gives every pane its one
    # chance, and returning to the top after leaves a test's own assertions
    # unaffected by where that walk ended.
    def scroll_through_page
      height = page.evaluate_script("window.innerHeight")
      total = page.evaluate_script("document.body.scrollHeight")
      offset = 0
      while offset < total
        # instant, not the CSS "smooth" scroll-behavior the gallery's own
        # in-page renderer links rely on: a smooth scroll is still animating
        # toward the previous step when the next one interrupts it, so the
        # page barely moves and a pane between the start and end position
        # never becomes visible at all.
        page.execute_script("window.scrollTo({ top: arguments[0], behavior: 'instant' })", offset)
        sleep 0.05
        offset += height
      end
      page.execute_script("window.scrollTo({ top: 0, behavior: 'instant' })")
    end

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
