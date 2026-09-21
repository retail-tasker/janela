module Janela
  # Takes a snapshot from serialisable arguments so a host can schedule it
  # with whatever runs its jobs. Each pane uses its model's default scope; a
  # host that scopes by tenant writes its own job around Snapshot.take and
  # passes on: (ADR 009).
  class SnapshotJob < ActiveJob::Base
    # ActiveJob cannot serialise a relation, which is why on: is not an
    # argument here, but it serialises a record through its GlobalID, so an
    # owner crosses the queue boundary without anything new (ADR 033).
    def perform(name:, panes:, owner: nil, filters: {})
      Snapshot.take(name: name, owner: owner, filters: filters) do |take|
        panes.each do |pane|
          pane = pane.to_h.stringify_keys
          model = Janela.definition!(pane.fetch("model")).model
          take.pane(model, pane.fetch("measure").to_sym,
                    by: pane["by"]&.to_sym, granularity: pane["granularity"], limit: pane["limit"])
        end
      end
    end
  end
end
