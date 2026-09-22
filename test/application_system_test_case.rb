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
    # What each pass left behind, kept on the instance so wait_for_frames can
    # say it if it goes on to time out. Behind an environment variable this was
    # lost twice on the one day it mattered, which is an argument for a failure
    # carrying its own evidence rather than for remembering a flag (#48).
    def scroll_through_page(passes: 4)
      @walk_history = []
      watch_intersections
      passes.times do
        walk_the_page
        left = unstarted_panes
        @walk_history << left
        return if left.empty?
      end
    end

    # An IntersectionObserver of our own on every pane, so a pane that never
    # fetches can be told apart from a pane the browser never considered
    # visible. Turbo's lazy loading is driven by exactly this, and three
    # explanations for the strand have now been disproved by measuring the
    # pane rather than reasoning about it (#48).
    def watch_intersections
      page.execute_script(<<~JS)
        window.janelaSeen = window.janelaSeen || {}
        if (!window.janelaWatcher) {
          window.janelaWatcher = new IntersectionObserver((entries) => {
            for (const entry of entries) {
              const id = entry.target.id
              const was = window.janelaSeen[id] || { fired: 0, everIntersected: false, maxRatio: 0 }
              window.janelaSeen[id] = {
                fired: was.fired + 1,
                everIntersected: was.everIntersected || entry.isIntersecting,
                maxRatio: Math.max(was.maxRatio, entry.intersectionRatio)
              }
            }
          })
        }
        document.querySelectorAll("turbo-frame[src]").forEach((p) => window.janelaWatcher.observe(p))
      JS
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
              const asked = p.dataset.janelaAsked || ""
              const src = p.getAttribute("src") || ""
              return {
                id: p.id,
                top: Math.round(box.top + window.scrollY),
                w: Math.round(box.width),
                h: Math.round(box.height),
                display: getComputedStyle(p).display,
                // Janela's own controller aborts a request whose URL differs
                // from what it asked for and re-requests, at most twice. Past
                // that it returns without scheduling one, which would leave a
                // pane with no request, no busy and no complete: the stranded
                // signature exactly. These say whether that is what happened.
                seen: (window.janelaSeen || {})[p.id] || null,
                // IntersectionObserver clips against every ancestor's overflow;
                // getBoundingClientRect does not. An element whose own rect is
                // in the viewport can still never intersect (#48).
                clippers: (() => {
                  const out = []
                  for (let el = p.parentElement; el && el !== document.body; el = el.parentElement) {
                    const st = getComputedStyle(el)
                    if (st.overflow !== "visible" || st.contentVisibility === "hidden" || st.display === "none") {
                      const b = el.getBoundingClientRect()
                      out.push(`${el.tagName.toLowerCase()}.${(el.className || "").toString().trim().split(/\s+/).join(".")}` +
                               ` overflow=${st.overflow} cv=${st.contentVisibility}` +
                               ` top=${Math.round(b.top)} bottom=${Math.round(b.bottom)} h=${Math.round(b.height)}`)
                    }
                  }
                  return out
                })(),
                corrections: p.janelaCorrections || 0,
                correctedFor: (p.janelaCorrectedFor || "").slice(-46),
                hasRequest: !!p.janelaRequest,
                askedMatchesSrc: asked === "" || asked === new URL(src, location.origin).href,
                asked: asked.slice(-46),
                src: src.slice(-46),
                page: height,
                viewport: window.innerHeight
              }
            })
        })()
      JS
    end

    def walk_the_page
      height = page.evaluate_script("window.innerHeight")
      total = page.evaluate_script("document.body.scrollHeight")
      # Half a viewport, not a whole one. Stepping by the full height gives a
      # pane that straddles a step boundary exactly one window in which it is
      # visible, and the browser has to compute an intersection inside that
      # one window or the pane never fetches. Overlapping the steps gives
      # every pane at least two (#48).
      step = (height / 2.0).ceil
      offset = 0
      while offset < total
        # instant, not the CSS "smooth" scroll-behavior the gallery's own
        # in-page renderer links rely on: a smooth scroll is still animating
        # toward the previous step when the next one interrupts it, so the
        # page barely moves and a pane between the start and end position
        # never becomes visible at all.
        page.execute_script("window.scrollTo({ top: arguments[0], behavior: 'instant' })", offset)
        sleep 0.05
        offset += step
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
          raise "the dashboard never became ready for a click: #{state.except('ready').to_json}\n" \
                "  the walk made #{@walk_history&.size || 0} passes.\n" \
                "  what each left: #{(@walk_history || []).to_json}"
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
