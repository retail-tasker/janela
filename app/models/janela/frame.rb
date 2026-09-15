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
  end
end
