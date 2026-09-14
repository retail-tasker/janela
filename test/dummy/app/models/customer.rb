class Customer < ApplicationRecord
  has_many :orders

  # An associated model keeps its own Ransack allowlist. Janela only owns
  # the allowlist of the model its dimensions are declared on.
  def self.ransackable_attributes(_auth_object = nil)
    %w[region]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end
end
