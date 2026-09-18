# The page ADR 027 means by a gallery: a host page, built from janela_pane
# and the enumerations Janela exposes (Janela.renderers, Janela.granularities,
# Janela.offered_limits, Janela.definitions), never from a Janela constant
# reached into directly (#39).
#
# Sectioned by renderer rather than by model: a reader comes here asking "what
# does a bar chart look like", not "what can Order do", so the kind of
# visualisation is the heading and a model is one demonstration under it.
class GalleryController < ApplicationController
  # A year of seed data bucketed by day is a smear of 365 points; month is
  # what the rest of this demo already buckets placed_on by (the homepage
  # pane, the snapshot fixtures), so the line example matches rather than
  # inventing its own answer.
  LINE_GRANULARITY = "month"

  # One entry per model demonstrating one renderer: what to draw it with, or
  # why it cannot be drawn here. A model with no measure at all cannot
  # demonstrate any renderer, since every query needs one.
  Entry = Struct.new(:model, :renderer, :measure, :dimension, :granularity, :reason, keyword_init: true) do
    def available?
      measure.present?
    end

    def declaration
      parts = [ "janela_pane #{model}, :#{measure}" ]
      parts << "by: :#{dimension}" if dimension
      parts << "as: :#{renderer}" unless renderer == "table"
      parts << "granularity: :#{granularity}" if granularity
      parts.join(", ")
    end

    # Only a line's dimension buckets by granularity; a bar's is categorical
    # and a table has none at all.
    def time_dimension?
      renderer == "line"
    end
  end

  def show
    @definitions = Janela.definitions
    @galleries = Janela.renderers.map { |renderer| [ renderer, @definitions.map { |definition| entry_for(definition, renderer) } ] }
  end

  private
    # table needs nothing but a measure; bar wants a dimension that is not a
    # time one, and line wants one that is, so each renderer is demonstrated
    # against the first dimension of the kind it needs, or not at all.
    def entry_for(definition, renderer)
      measure = definition.measures.keys.first
      return Entry.new(model: definition.model, renderer: renderer, reason: "#{definition.model} declares no measure") if measure.nil?

      categorical = definition.dimensions.values.find { |dimension| !dimension.time? }
      time = definition.dimensions.values.find(&:time?)

      case renderer
      when "table"
        Entry.new(model: definition.model, renderer: renderer, measure: measure)
      when "bar"
        categorical ? Entry.new(model: definition.model, renderer: renderer, measure: measure, dimension: categorical.name) :
                       Entry.new(model: definition.model, renderer: renderer, reason: "#{definition.model} declares no dimension besides a time one")
      when "line"
        time ? Entry.new(model: definition.model, renderer: renderer, measure: measure, dimension: time.name, granularity: LINE_GRANULARITY) :
               Entry.new(model: definition.model, renderer: renderer, reason: "#{definition.model} declares no time dimension")
      end
    end
end
