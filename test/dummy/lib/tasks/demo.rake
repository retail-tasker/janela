namespace :demo do
  desc "Reset the public demo to its seeded state, throwing away whatever visitors have made"
  task reset: :environment do
    # The demo is open for anyone to edit, which is the point of it, so this is
    # destructive on purpose. It refuses to run anywhere that is not the demo,
    # because the same command against a real application would be a very bad
    # afternoon. DEMO_HOST is set by the demo's own deploy.
    unless ENV["DEMO_HOST"].present? || ENV["FORCE"] == "1"
      abort "demo:reset refuses to run here: DEMO_HOST is not set. Use FORCE=1 if you mean it."
    end

    # The visits dashboard is arranged on purpose, through the agent tools,
    # and its numbers are real, so it is the one frame a reset keeps (ADR 058).
    # Its owner is a customer the reset is about to delete, so it is handed to
    # the new first one below.
    keep = Janela::Frame.find_by(name: PageView::FRAME)

    Janela::Pane.where.not(frame_id: keep&.id).delete_all
    Janela::Frame.where.not(id: keep&.id).delete_all
    Janela::Snapshot.delete_all
    Order.delete_all
    Customer.delete_all

    # The seeds are deterministic, so a reset restores the same numbers rather
    # than a new random year that would make every screenshot a lie.
    load Rails.root.join("db/seeds.rb")
    keep&.update!(owner: Customer.order(:name).first)

    Rails.logger.info("demo:reset restored #{Order.count} orders and #{Janela::Frame.count} frames")
    puts "Reset: #{Order.count} orders, #{Janela::Frame.count} frames, #{Janela::Snapshot.count} snapshots."
  end
end
