module Janela
  # A dashboard, as data: a name, a grid, and the panes it holds (ADR 012).
  # A frame is created at runtime by a host, a script or an agent, so nothing
  # about a dashboard has to be deployed.
  class Frame < ActiveRecord::Base
    COLUMNS = (1..12).freeze
    GAPS = (0..8).freeze

    # Janela sets nothing here and reads nothing from it. The column exists so
    # a multi tenant host's Pundit Scope has something to filter on (ADR 014).
    belongs_to :owner, polymorphic: true, optional: true

    has_many :panes, -> { order(:position) }, dependent: :destroy, inverse_of: :frame

    validates :name, presence: true
    validates :columns, inclusion: { in: COLUMNS }
    validates :gap, inclusion: { in: GAPS }

    # Positions are kept contiguous so that moving a pane has no gap to fall
    # into and a new pane's position is never a hole. Called after a pane is
    # removed rather than on read, because reading a frame is the common case.
    def resequence_panes!
      panes.order(:position).each_with_index do |pane, index|
        pane.update_columns(position: index + 1) unless pane.position == index + 1
      end
    end
  end
end
