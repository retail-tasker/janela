# Records a PageView for every full page a visitor opens, so the demo can show
# its own traffic. A Turbo Frame request (every pane of every dashboard), a
# prefetch, a robot, a JSON call or a redirect is not someone opening a screen.
#
# Failing to record is reported and never breaks the page that was asked for.
module RecordsPageViews
  extend ActiveSupport::Concern

  ROBOTS = /bot|crawl|spider|slurp|curl|wget|python|monitor|uptime|headless/i

  included do
    after_action :record_page_view
  end

  private
    def record_page_view
      return unless countable_page_view?

      PageView.record(controller: controller_path, action: action_name, path: request.path)
    rescue StandardError => error
      Rails.error.report(error, handled: true, context: { path: request.path })
    end

    def countable_page_view?
      request.get? && response.successful? && response.media_type == "text/html" && !turbo_frame_request? &&
        request.headers["Sec-Purpose"].blank? && request.headers["X-Sec-Purpose"].blank? &&
        !request.user_agent.to_s.match?(ROBOTS)
    end
end
