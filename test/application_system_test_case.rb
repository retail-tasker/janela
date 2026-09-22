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
    # One pass is not enough under load. A pane fetches when the browser's own
    # IntersectionObserver reports it, and that callback is asynchronous: a
    # step that scrolls past an element and moves on 50ms later can leave
    # before the callback has run, so the pane never fetches at all. No amount
    # of waiting afterwards changes a request that was never made, which is
    # why raising wait_for_frames' ceiling helped a great deal and did not
    # close #48. Walking again until every pane has started is the thing this
    # was always trying to achieve, and costs a settled page one extra check.
    def scroll_through_page(passes: 4)
      passes.times do |pass|
        walk_the_page
        left = unstarted_panes
        return if left.empty?

        ENV["JANELA_WALK_DEBUG"] && warn("walk pass #{pass + 1} left #{left.to_json}")
      end
    end

    # Panes that have neither started nor finished, with where they sit and how
    # tall the page is, so a skip can be told apart from a walk that stopped
    # short of the bottom.
    def unstarted_panes
      page.evaluate_script(<<~JS)
        (() => {
          const height = document.body.scrollHeight
          return [...document.querySelectorAll("turbo-frame[src]")]
            .filter((p) => !p.hasAttribute("complete") && !p.hasAttribute("busy"))
            .map((p) => {
              const box = p.getBoundingClientRect()
              return { id: p.id, top: Math.round(box.top + window.scrollY), page: height }
            })
        })()
      JS
    end

    def walk_the_page
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

    # The ceiling is generous because it is a safety net rather than an
    # assertion: the loop returns the moment every pane is ready, so a
    # passing run costs nothing. At twice the default it was four seconds,
    # which the gallery exceeded when it ran inside the full suite rather
    # than alone, failing roughly one run in three while passing 20 of 20
    # on its own. Measured, not guessed, and the page reached the right
    # state every time once it was allowed to finish.
    def wait_for_frames(timeout: Capybara.default_max_wait_time * 6)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
      loop do
        state = frame_readiness
        return if state["ready"]

        if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
          raise "the dashboard never became ready for a click: #{state.except('ready').to_json}"
        end

        sleep 0.05
      end
    end

    # Reported rather than reduced to a boolean, so a timeout names what was
    # still outstanding rather than only that something was. A dozen identical
    # "never became ready" failures say nothing about which of the three
    # possible causes it is: Stimulus never arriving, a controller never
    # connecting, or a pane's own request never landing (#48).
    def frame_readiness
      page.evaluate_script(<<~JS)
        (() => {
          const frames = [...document.querySelectorAll("[data-controller~='janela--frame']")]
          const panes = [...document.querySelectorAll("turbo-frame[src]")]
          const outstanding = panes.filter((p) => !p.hasAttribute("complete") || p.hasAttribute("busy"))
          const unconnected = window.Stimulus
            ? frames.filter((el) => !window.Stimulus.getControllerForElementAndIdentifier(el, "janela--frame")).length
            : frames.length
          return {
            ready: frames.length === 0 || !!(window.Stimulus && unconnected === 0 && outstanding.length === 0),
            stimulus: !!window.Stimulus,
            frames: frames.length,
            unconnected: unconnected,
            panes: panes.length,
            outstanding: outstanding.map((p) => ({
              id: p.id,
              busy: p.hasAttribute("busy"),
              src: (p.getAttribute("src") || "").slice(-70)
            })),
            path: location.pathname
          }
        })()
      JS
    end

    # A page opened with a plain visit is in the DOM before its stylesheets
    # are: a link element's `sheet` is null until the file has loaded and
    # parsed, and until then every computed style is the initial value and
    # every box is the width unstyled content happens to be. Two of eighty
    # full suite runs on a CI runner read scroll-behavior as "auto" for that
    # reason, and none of 400 on a faster machine did, which is what a test
    # racing a network fetch looks like.
    #
    # Only needed where a test uses Capybara's own visit: this class's
    # override already waits for panes, which cannot finish before the page
    # has loaded.
    def wait_for_stylesheets(timeout: Capybara.default_max_wait_time)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
      loop do
        ready = page.evaluate_script(<<~JS)
          [...document.querySelectorAll('link[rel="stylesheet"]')].every((link) => link.sheet)
        JS
        return if ready
        raise "a stylesheet never loaded" if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

        sleep 0.05
      end
    end

    # The five elements reaching furthest past the viewport, so a page that
    # scrolls sideways names the thing doing it rather than only the number
    # of pixels (#50).
    def overflowing_elements
      page.evaluate_script(<<~JS).join("\n")
        (() => {
          const limit = document.documentElement.clientWidth
          return [...document.querySelectorAll("*")]
            .map((el) => [el, el.getBoundingClientRect().right])
            .filter(([, right]) => right > limit + 1)
            .sort((a, b) => b[1] - a[1])
            .slice(0, 5)
            .map(([el, right]) => {
              const classes = typeof el.className === "string" && el.className.trim()
                ? "." + el.className.trim().split(/\s+/).join(".")
                : ""
              return `  ${Math.round(right)}px past 0  ${el.tagName.toLowerCase()}${el.id ? "#" + el.id : ""}${classes}`
            })
        })()
      JS
    end
end
