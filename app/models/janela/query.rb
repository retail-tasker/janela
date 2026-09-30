module Janela
  # The query behind one pane: a measure, optionally grouped by a dimension,
  # rendered as a single value, a table or a chart. A query ignores filters on
  # its own dimension so that clicking a value re-scopes the other panes
  # rather than collapsing this one to the value clicked. A query read from a
  # snapshot shows stored results and cannot be clicked at all.
  class Query
    RENDERERS = %w[table bar line doughnut pie].freeze

    # Drawn by Chart.js on a canvas, and so blank without a chart runtime.
    CANVAS = %w[bar line].freeze

    # Drawn on the server as SVG instead (ADR 046).
    RINGS = %w[doughnut pie].freeze

    # Palette slots before the neutral. Colour is chosen by position and never
    # cycled: a ninth category drawn in the first colour would be two
    # categories the same beside a legend that says they differ (ADR 046).
    SERIES = 8

    # The steps a chart's height may take (ADR 047). Pane::HEIGHTS is the same
    # range for a stored row, and a test holds the two together.
    HEIGHTS = (1..5).freeze

    # The steps a single value's prominence may take (ADR 050).
    PROMINENCES = (1..3).freeze

    attr_reader :definition, :measure, :dimension, :renderer, :limit, :height, :prominence, :filters, :fixed, :default, :snapshot

    # The helper renders the turbo frame and the controller renders its
    # replacement, so both derive the id the same way from the same parameters.
    def self.turbo_frame_id(model:, measure:, by: nil, as: :table, granularity: nil, limit: nil, snapshot: nil)
      parts = [ "janela", ("snapshot_#{snapshot.id}" if snapshot), model.model_name.route_key, measure, by,
                (granularity if by), (as unless by.nil?), ("top#{limit}" if by && limit) ]
      parts.compact.join("_")
    end

    def initialize(definition:, measure:, dimension: nil, renderer: "table", granularity: nil, limit: nil, height: nil, prominence: nil, filters: {}, fixed: {}, default: {}, snapshot: nil, title: nil)
      @definition = definition
      @title = title
      @measure = measure
      @dimension = dimension
      @renderer = renderer.to_s
      @filters = filters
      @fixed = fixed
      @default = default
      @snapshot = snapshot

      raise BadRequest, "unknown pane renderer #{renderer.inspect}" unless RENDERERS.include?(@renderer)
      @granularity = Dimension.granularity!(granularity) if granularity.present?
      @limit = definition.limit!(limit) if limit.present?
      @height = height!(height) if height.present?
      @prominence = prominence!(prominence) if prominence.present?
    end

    def model
      definition.model
    end

    # Every number this pane renders goes through here, so a table cell, a
    # single value and a chart tooltip cannot disagree about what the measure
    # means (ADR 020).
    def format(value)
      definition.measure!(measure).format(value)
    end

    def single_value?
      dimension.nil?
    end

    def time?
      !single_value? && dimension_definition.time?
    end

    def frozen?
      !snapshot.nil?
    end

    def granularity
      @granularity || (dimension_definition.granularity if time?)
    end

    # A stored pane is the record of a moment and is not clickable (ADR 009).
    # A time pane is: a bucket writes the pair of conditions for its range
    # (ADR 045).
    def clickable?
      !single_value? && !frozen?
    end

    def chart?
      !single_value? && CANVAS.include?(renderer)
    end

    # A height means a box only where there is a canvas to fill it. A ring, a
    # table and a single value ignore one, so switching a pane between
    # renderers never invalidates it (ADR 047).
    # Only a single value has a headline number to make more or less of. A
    # table, a chart and a ring ignore one, so a pane switched between renderers
    # keeps what it had (ADR 050).
    def prominent?
      single_value? && !prominence.nil?
    end

    def boxed?
      chart? && !height.nil?
    end

    def ring?
      !single_value? && RINGS.include?(renderer)
    end

    # A part of a whole cannot be negative, and a ring of nothing draws
    # nothing. Either way the pane is a table that says why, not a wrong
    # picture (ADR 046).
    def hole?
      renderer == "doughnut"
    end

    def ringable?(result)
      values = result.values.map(&:to_f)
      values.none?(&:negative?) && values.sum.positive?
    end

    # The custom property a category at this position is drawn with.
    def series_property(index)
      index < SERIES ? "--janela-series-#{index + 1}" : "--janela-series-other"
    end

    # One entry per label, in result order, with the arc it covers. A zero is
    # kept for the legend and has no arc. The filter is the one a click on
    # that label toggles, so the slice and its legend row cannot disagree.
    CENTRE = 50.0
    OUTER = 48.0
    INNER = 27.0

    Slice = Struct.new(:label, :formatted, :property, :click, :selected, :fraction, :from, keyword_init: true) do
      # The SVG path of this slice on a 100 by 100 canvas, from twelve o'clock
      # clockwise, or nil when it covers nothing. One slice covering the whole
      # circle is two half arcs, since an arc from a point to itself is not
      # drawn. A doughnut's hole is a second sub-path, cut out by the
      # stylesheet's even-odd fill rule.
      def path(hole:)
        return unless fraction.positive?
        return whole(hole) if fraction >= 0.9999

        large = fraction > 0.5 ? 1 : 0
        outer_from, outer_to = point(OUTER, from), point(OUTER, from + fraction)
        if hole
          inner_from, inner_to = point(INNER, from), point(INNER, from + fraction)
          "M #{outer_from} A #{OUTER} #{OUTER} 0 #{large} 1 #{outer_to} L #{inner_to} A #{INNER} #{INNER} 0 #{large} 0 #{inner_from} Z"
        else
          "M #{CENTRE} #{CENTRE} L #{outer_from} A #{OUTER} #{OUTER} 0 #{large} 1 #{outer_to} Z"
        end
      end

      private
        def whole(hole)
          circle = ->(radius) { "M #{CENTRE} #{CENTRE - radius} A #{radius} #{radius} 0 1 1 #{CENTRE} #{CENTRE + radius} A #{radius} #{radius} 0 1 1 #{CENTRE} #{CENTRE - radius} Z" }
          hole ? "#{circle.(OUTER)} #{circle.(INNER)}" : circle.(OUTER)
        end

        def point(radius, turns)
          angle = turns * 2 * Math::PI - Math::PI / 2
          format("%.3f %.3f", CENTRE + radius * Math.cos(angle), CENTRE + radius * Math.sin(angle))
        end
    end

    def slices(result)
      total = result.values.sum(&:to_f)
      from = 0.0
      result.each_with_index.map do |(label, measured), index|
        fraction = measured.to_f / total
        slice = Slice.new(label: label.to_s, formatted: format(measured), property: series_property(index),
                          click: (click_data(label) if clickable?), selected: selected?(label), fraction: fraction, from: from)
        from += fraction
        slice
      end
    end

    def turbo_frame_id
      self.class.turbo_frame_id(model: model, measure: measure, by: dimension, as: renderer,
                          granularity: @granularity, limit: limit, snapshot: snapshot)
    end

    # A pane row may carry its own title, which is the first analyst authored
    # text the gem renders. It is escaped like any other string (ADR 014).
    def title
      return @title if @title.present?

      base = if single_value?
        measure.to_s.humanize
      else
        by = "#{measure.to_s.humanize} by #{dimension.to_s.humanize}"
        time? ? "#{by} per #{granularity}" : by
      end
      frozen? ? "#{base} as of #{snapshot.taken_at.strftime('%-d %b %Y')}" : base
    end

    # What identifies this pane's data inside a snapshot.
    def lookup_key
      { "model" => model.model_name.route_key, "measure" => measure.to_s, "dimension" => dimension&.to_s,
        "granularity" => granularity&.to_s, "limit" => limit }
    end

    def result(on: nil)
      return snapshot.stored_result(self) if frozen?

      # Default, then fixed, then the reader's: a frame's own permanent
      # filter narrows first, a host's per-record filter narrows again, and
      # both apply even on this pane's own dimension, unlike the reader's
      # selection, which this pane shows the alternatives to (ADR 040, 043).
      on = definition.narrow(on || model.all, default) if default.present?
      on = definition.narrow(on || model.all, fixed) if fixed.present?
      return time_result(on) if time?

      definition.query(measure, by: dimension, where: applicable_filters, on: on, granularity: granularity, limit: limit)
    end

    # The two filters a click on this label writes, for a time pane: the start
    # of its bucket and the start of the next (ADR 045).
    def range_for(label)
      from, to = dimension_definition.bounds(@buckets.fetch(label.to_s), granularity)
      { "#{ransack_name}_gteq" => from, "#{ransack_name}_lt" => to }
    end

    # The data attributes a table button or legend row carries: one key and
    # value for a category, the pair of conditions for a bucket.
    def click_data(label)
      if time?
        { janela__frame_filters_param: range_for(label).to_json }
      else
        key, value = filter_params(label)
        key ? { janela__frame_key_param: key, janela__frame_value_param: value } : nil
      end
    end

    # The Ransack key and value a click on this label should toggle. A null
    # group filters with the null predicate, not an empty string (ADR 009 has
    # no say here; see issue #21).
    # A click writes _in whether one value is selected or five, so there is one
    # shape in the controller, the view and a stored snapshot. A hand written
    # _eq link is still read, since a URL somebody already sent should not stop
    # working to suit us (ADR 024).
    def filter_params(label)
      return [ nil, nil ] unless clickable? && !time?
      return [ "#{ransack_name}_null", "1" ] if label.to_s == Dimension::NONE

      [ "#{ransack_name}_in", label.to_s ]
    end

    # Every label in this pane paired with the filter it toggles, for a chart
    # to look up by label when a bar is clicked.
    def filters_for(labels)
      return {} unless clickable?
      return labels.to_h { |label| [ label.to_s, range_for(label) ] } if time?

      labels.to_h { |label| [ label.to_s, filter_params(label) ] }
    end

    # The filter on this pane's own dimension is not applied to its query, but
    # it is what the user clicked here, so the view highlights it.
    # Every value of this pane's own dimension the filters name. A set, because
    # a dimension can hold more than one (ADR 024), and the null group is in it
    # like any other label.
    def selected_values
      return [] unless clickable?
      return selected_buckets if time?

      values = Array(filter("#{ransack_name}_in")) + Array(filter("#{ransack_name}_eq"))
      values = values.map(&:to_s)
      values << Dimension::NONE if filter("#{ransack_name}_null").present?
      values
    end

    def selected?(label)
      selected_values.include?(label.to_s)
    end

    private
      def filter(key)
        filters[key] || filters[key.to_sym]
      end

      def dimension_definition
        definition.dimension!(dimension)
      end

      def ransack_name
        dimension_definition.ransack_name
      end

      # A time pane's series is read as buckets, not labels, and the buckets
      # are kept: the labels alone cannot say what range a click covers.
      def time_result(on)
        series = definition.series(measure, by: dimension, where: applicable_filters, on: on, granularity: granularity)
        @buckets = series.keys.to_h { |bucket| [ dimension_definition.label(bucket, granularity), bucket ] }
        series.transform_keys { |bucket| dimension_definition.label(bucket, granularity) }
      end

      # The buckets that lie wholly inside the range the filters name. Janela
      # writes both ends, so a range with one is somebody else's and selects
      # nothing here. Read before the first result there are no buckets yet.
      def selected_buckets
        from, to = filter("#{ransack_name}_gteq"), filter("#{ransack_name}_lt")
        return [] if from.blank? || to.blank? || @buckets.nil?

        from, to = Time.zone.parse(from.to_s), Time.zone.parse(to.to_s)
        return [] if from.nil? || to.nil?

        @buckets.select { |_, bucket|
          start, finish = dimension_definition.span(bucket, granularity)
          start >= from && finish <= to
        }.keys
      end

      def prominence!(value)
        step = Integer(value.to_s, exception: false)
        raise BadRequest, "prominence must be a whole number from #{PROMINENCES.first} to #{PROMINENCES.last}, got #{value.inspect}" unless PROMINENCES.cover?(step)

        step
      end

      def height!(value)
        step = Integer(value.to_s, exception: false)
        raise BadRequest, "height must be a whole number from #{HEIGHTS.first} to #{HEIGHTS.last}, got #{value.inspect}" unless HEIGHTS.cover?(step)

        step
      end

      def applicable_filters
        return filters if single_value?

        filters.reject { |key, _| key.to_s.start_with?(ransack_name) }
      end
  end
end
