module Janela
  # What an agent can do to a dashboard, as plain Ruby (ADR 053). A host builds
  # one where it knows who is asking, hands it the answer to "what may this
  # caller read", and registers #all with whatever MCP library it runs. Janela
  # registers nothing and serves nothing, and depends on no MCP library.
  #
  #   tools = Janela::Tools.new(scope: ->(model) { policy_scope(model) })
  #   tools.all                                  # name, description, input_schema, read_only
  #   tools.call("read_pane", pane_id: 4)        # a Hash, or a Janela::Error
  #
  # Every read passes the host's relation as on:, because Query#result with no
  # on: reads the model's default scope, and the refusal in ADR 032 lives in the
  # controller. Frames and panes are found through the same scope, so what a
  # caller may change is what it may see.
  class Tools
    Tool = Data.define(:name, :description, :input_schema, :read_only)

    # The attributes of a pane a caller may set: the ones the README names. The
    # frame, the position and the timestamps are not an agent's to write.
    PANE_ATTRIBUTES = %w[kind model measure dimension renderer granularity limit span title height prominence
                         companions heading body link partial].freeze
    DIRECTIONS = %w[up down].freeze
    READS = %w[describe_vocabulary list_frames get_frame read_pane].freeze
    WRITES = %w[add_pane update_pane remove_pane move_pane].freeze

    def initialize(scope: nil, write: false)
      unless scope.respond_to?(:call)
        raise Unscoped, "Janela::Tools was built without a scope. Pass the answer to what this caller may read: " \
                        "Janela::Tools.new(scope: ->(model) { policy_scope(model) }). A tool with no scope would " \
                        "read every row of every model, which is what ADR 032 refuses."
      end

      @scope = scope
      @write = write
    end

    # What there is to register. Needs no scope, because a definition says
    # nothing about whose data it will read; the scope matters when a tool is
    # called, and a host usually learns who is calling only then (ADR 053).
    def self.all(write: false)
      names = write ? READS + WRITES : READS
      names.map { |name| definitions.fetch(name) }
    end

    def all
      self.class.all(write: @write)
    end

    # Arguments may arrive with string keys, as they do from a protocol.
    # Anything a tool refuses is a Janela::Error, which an adapter reports to
    # the agent as the tool's own error rather than a crash.
    def call(name, arguments = {})
      raise NotFound, "no tool named #{name}" unless all.any? { |tool| tool.name == name.to_s }

      __send__(name, **arguments.to_h.symbolize_keys)
    rescue ArgumentError => error
      raise error unless error.message.match?(/unknown keyword|missing keyword/)

      raise BadRequest, "#{name}: #{error.message}"
    end

    private
      def describe_vocabulary
        { models: Janela.definitions.map { |definition| model_hash(definition) },
          renderers: Janela.renderers.map(&:to_s),
          granularities: Janela.granularities.map(&:to_s),
          limits: Pane::OFFERED_LIMITS }
      end

      def list_frames
        { frames: scoped(Frame).includes(:panes).order(:id).map { |frame| frame_hash(frame).merge(pane_count: frame.panes.size) } }
      end

      def get_frame(frame_id:)
        frame = frame_in_scope(frame_id)
        frame_hash(frame).merge(panes: frame.panes.map { |pane| pane_hash(pane) })
      end

      def read_pane(pane_id:, filters: {})
        pane = pane_in_scope(pane_id)
        raise BadRequest, "pane #{pane.id} holds #{pane.kind}, not a query, so it has no values" unless pane.query?

        query = pane.query(filters: filters.to_h.stringify_keys)
        result = query.result(on: scoped(pane.definition.model))
        reading = { pane_id: pane.id, measure: pane.measure, dimension: pane.dimension }
        return reading.merge(value: result&.to_f, formatted: query.format(result)) if query.single_value?

        reading.merge(values: result.transform_values(&:to_f), formatted: result.transform_values { |value| query.format(value) })
      end

      def add_pane(frame_id:, **attributes)
        frame = frame_in_scope(frame_id)
        pane = frame.panes.build(pane_attributes(attributes))
        pane.save || refuse(pane)
        pane_hash(pane)
      end

      def update_pane(pane_id:, **attributes)
        pane = pane_in_scope(pane_id)
        pane.update(pane_attributes(attributes)) || refuse(pane)
        pane_hash(pane)
      end

      def remove_pane(pane_id:)
        pane = pane_in_scope(pane_id)
        pane.destroy
        pane.frame.resequence_panes!
        { removed: pane.id }
      end

      def move_pane(pane_id:, direction:)
        raise BadRequest, "direction is #{DIRECTIONS.join(' or ')}, not #{direction.inspect}" unless DIRECTIONS.include?(direction.to_s)

        pane = pane_in_scope(pane_id)
        direction.to_s == "up" ? pane.move_up : pane.move_down
        pane_hash(pane.reload)
      end

      # The host's relation for a model, and a refusal if it is not one. A scope
      # that answers with an Array or nil has not scoped anything.
      def scoped(model)
        relation = @scope.call(model)
        return relation if relation.respond_to?(:where)

        raise Unscoped, "the scope answered #{relation.class} for #{model.name}, not a relation. " \
                        "It should return what policy_scope(#{model.name}) returns."
      end

      def frame_in_scope(id)
        scoped(Frame).find_by(id: id) || raise(NotFound, "no frame #{id}")
      end

      # One query, with the scope as a subquery: a pane is reachable only
      # through a frame the caller may see.
      def pane_in_scope(id)
        Pane.where(frame_id: scoped(Frame).select(:id)).find_by(id: id) || raise(NotFound, "no pane #{id}")
      end

      def pane_attributes(attributes)
        unknown = attributes.keys.map(&:to_s) - PANE_ATTRIBUTES
        raise BadRequest, "not a pane attribute: #{unknown.join(', ')}. A pane takes #{PANE_ATTRIBUTES.join(', ')}." if unknown.any?

        attributes.transform_keys(&:to_s)
      end

      def refuse(record)
        raise BadRequest, record.errors.full_messages.to_sentence
      end

      def model_hash(definition)
        { name: definition.model.model_name.route_key,
          measures: definition.measures.keys.map(&:to_s),
          dimensions: definition.dimensions.values.map { |dimension| { name: dimension.name.to_s, time: dimension.time? } } }
      end

      def frame_hash(frame)
        frame.attributes.slice("id", "name", "columns", "gap", "key", "owner_type", "owner_id", "default_model", "default_where").compact.symbolize_keys
      end

      def pane_hash(pane)
        pane.attributes.slice("id", "position", "span", *(PANE_ATTRIBUTES - %w[span])).compact.symbolize_keys
      end

    class << self
      private
        def definitions
          {
            "describe_vocabulary" => tool("describe_vocabulary", read: true,
              description: "The models, measures, dimensions, renderers and granularities that can be asked for. Offer nothing else.",
              properties: {}),
            "list_frames" => tool("list_frames", read: true,
              description: "The frames the caller may see: id, name, owner and how many panes each holds.",
              properties: {}),
            "get_frame" => tool("get_frame", read: true, required: %w[frame_id],
              description: "One frame with its panes in position order.",
              properties: { frame_id: { type: "integer" } }),
            "read_pane" => tool("read_pane", read: true, required: %w[pane_id],
              description: "The values a query pane shows, read through the caller's scope. Filters are Ransack predicates on declared dimensions.",
              properties: { pane_id: { type: "integer" }, filters: { type: "object" } }),
            "add_pane" => tool("add_pane", required: %w[frame_id],
              description: "Add a pane to the end of a frame. A pane Janela would refuse is refused with its own reason.",
              properties: { frame_id: { type: "integer" } }.merge(pane_properties)),
            "update_pane" => tool("update_pane", required: %w[pane_id],
              description: "Change a pane's attributes. An invalid change leaves the pane as it was.",
              properties: { pane_id: { type: "integer" } }.merge(pane_properties)),
            "remove_pane" => tool("remove_pane", required: %w[pane_id],
              description: "Remove a pane and close the gap it leaves.",
              properties: { pane_id: { type: "integer" } }),
            "move_pane" => tool("move_pane", required: %w[pane_id direction],
              description: "Move a pane one place up or down its frame.",
              properties: { pane_id: { type: "integer" }, direction: { type: "string", enum: DIRECTIONS } })
          }
        end

        def tool(name, description:, properties:, read: false, required: [])
          Tool.new(name: name, description: description, read_only: read,
                   input_schema: { type: "object", properties: properties, required: required, additionalProperties: false })
        end

        def pane_properties
          { kind: { type: "string", enum: Pane::KINDS },
            model: { type: "string", description: "A model's route key, as describe_vocabulary lists it" },
            measure: { type: "string" },
            dimension: { type: "string" },
            renderer: { type: "string", enum: Janela.renderers.map(&:to_s) },
            granularity: { type: "string", enum: Janela.granularities.map(&:to_s) },
            limit: { type: "integer", minimum: Pane::LIMITS.min, maximum: Pane::LIMITS.max },
            span: { type: "integer", minimum: Pane::SPANS.min, maximum: Pane::SPANS.max },
            title: { type: "string" },
            height: { type: "integer", enum: Pane::HEIGHTS.to_a },
            prominence: { type: "integer", enum: Pane::PROMINENCES.to_a },
            companions: { type: "array", items: { type: "string" } },
            heading: { type: "string" },
            body: { type: "string" },
            link: { type: "string", description: "A path on this site, starting with /" },
            partial: { type: "string" } }
        end
    end
  end
end
