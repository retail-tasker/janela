module Janela
  # Takes a snapshot from serialisable arguments so a host can schedule it
  # with whatever runs its jobs.
  #
  # What rows each pane freezes is the host's answer rather than Janela's. A
  # host whose tenancy is enforced on its models says so with
  # scope: :model_default; a host whose tenancy lives in its policies
  # subclasses this and overrides scope_for, because a class name crosses the
  # queue where a relation cannot (ADR 034).
  class SnapshotJob < ActiveJob::Base
    # ActiveJob cannot serialise a relation, which is why on: is not an
    # argument here, but it serialises a record through its GlobalID, so an
    # owner crosses the queue boundary without anything new (ADR 033).
    def perform(name:, panes:, owner: nil, filters: {}, scope: nil)
      @name, @owner, @filters, @scope = name, owner, filters, scope&.to_sym

      Snapshot.take(name: name, owner: owner, filters: filters) do |take|
        panes.each do |pane|
          pane = pane.to_h.stringify_keys
          model = Janela.definition!(pane.fetch("model")).model
          take.pane(model, pane.fetch("measure").to_sym, on: scope_for(model),
                    by: pane["by"]&.to_sym, granularity: pane["granularity"], limit: pane["limit"])
        end
      end
    end

    private
      # What the job was told, so a subclass answering scope_for never has to
      # override perform or reach into ActiveJob's arguments to find it.
      attr_reader :name, :owner, :filters

      # The one question this job asks, and the one it will not answer on a
      # host's behalf: what rows does a pane freeze? A model's default scope
      # is the tenant's rows when tenancy is enforced on the models, and every
      # row when it lives in a policy, and nothing reachable from a job can
      # tell which application this is. Unanswered it refuses, because the
      # wrong answer here is frozen into a row and published (ADR 034).
      def scope_for(model)
        raise Unscoped, unanswered if @scope.nil?
        raise ArgumentError, "#{@scope.inspect} is not a scope Janela knows. Pass :model_default, " \
                             "or override scope_for in a subclass of Janela::SnapshotJob." unless @scope == :model_default

        model.all
      end

      def unanswered
        "Janela::SnapshotJob has not been told what rows to freeze. If your tenancy is enforced " \
        "on your models, a model's default scope is already the rows you mean, and saying so is " \
        "the whole of it:\n\n" \
        "  Janela::SnapshotJob.perform_later(name: \"September\", scope: :model_default, panes: [...])\n\n" \
        "If your scoping lives in your policies instead, that is every row of every model. " \
        "Answer in Ruby, where a relation is still a relation, and schedule your own job:\n\n" \
        "  class TenantSnapshotJob < Janela::SnapshotJob\n" \
        "    private def scope_for(model) = model.where(account: owner)\n" \
        "  end\n\n" \
        "docs/multi-tenancy.md has the wiring."
      end
  end
end
