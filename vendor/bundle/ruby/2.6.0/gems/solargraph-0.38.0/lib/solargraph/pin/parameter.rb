# frozen_string_literal: true

module Solargraph
  module Pin
    class Parameter < LocalVariable
      def return_type
        if @return_type.nil?
          @return_type = ComplexType.new
          found = param_tag
          @return_type = ComplexType.try_parse(*found.types) unless found.nil? or found.types.nil?
        end
        super
        @return_type
      end

      # The parameter's zero-based location in the block's signature.
      #
      # @return [Integer]
      def index
        closure.parameter_names.index(name)
      end

      # @param api_map [ApiMap]
      def typify api_map
        return return_type.qualify(api_map, closure.context.namespace) unless return_type.undefined?
        closure.is_a?(Pin::Block) ? typify_block_param(api_map) : typify_method_param(api_map)
      end

      def documentation
        tag = param_tag
        return '' if tag.nil? || tag.text.nil?
        tag.text
      end

      def try_merge! pin
        return false unless super && closure == pin.closure
        true
      end

      def probe api_map
        typify api_map
      end

      private

      # @return [YARD::Tags::Tag]
      def param_tag
        found = nil
        params = closure.docstring.tags(:param)
        params.each do |p|
          next unless p.name == name
          found = p
          break
        end
        if found.nil? and !index.nil?
          found = params[index] if params[index] && (params[index].name.nil? || params[index].name.empty?)
        end
        found
      end

      # @param api_map [ApiMap]
      # @return [ComplexType]
      def typify_block_param api_map
        if closure.is_a?(Pin::Block) && closure.receiver
          chain = Source::NodeChainer.chain(closure.receiver, filename)
          clip = api_map.clip_at(location.filename, location.range.start)
          locals = clip.locals - [self]
          meths = chain.define(api_map, closure, locals)
          meths.each do |meth|
            if meth.docstring.has_tag?(:yieldparam_single_parameter)
              type = chain.base.infer(api_map, closure, locals)
              if type.defined? && !type.subtypes.empty?
                bmeth = chain.base.define(api_map, closure, locals).first
                return type.subtypes.first.qualify(api_map, bmeth.context.namespace)
              end
            else
              yps = meth.docstring.tags(:yieldparam)
              unless yps[index].nil? or yps[index].types.nil? or yps[index].types.empty?
                return ComplexType.try_parse(yps[index].types.first).self_to(chain.base.infer(api_map, closure, locals).namespace).qualify(api_map, meth.context.namespace)
              end
            end
          end
        end
        ComplexType::UNDEFINED
      end

      # @param api_map [ApiMap]
      # @return [ComplexType]
      def typify_method_param api_map
        meths = api_map.get_method_stack(closure.full_context.namespace, closure.name, scope: closure.scope)
        # meths.shift # Ignore the first one
        meths.each do |meth|
          found = nil
          params = meth.docstring.tags(:param)
          if params.empty?
            params = see_reference(docstring, api_map)
          end
          params.each do |p|
            next unless p.name == name
            found = p
            break
          end
          if found.nil? and !index.nil?
            found = params[index] if params[index] && (params[index].name.nil? || params[index].name.empty?)
          end
          return ComplexType.try_parse(*found.types).qualify(api_map, meth.context.namespace) unless found.nil? || found.types.nil?
        end
        ComplexType::UNDEFINED
      end

      # @param heredoc [YARD::Docstring]
      # @param api_map [ApiMap]
      # @param skip [Array]
      # @return [Array<YARD::Tags::Tag>]
      def see_reference heredoc, api_map, skip = []
        heredoc.ref_tags.each do |ref|
          next unless ref.tag_name == 'param' && ref.owner
          result = resolve_reference(ref.owner.to_s, api_map, skip)
          return result unless result.nil?
        end
        []
      end

      # @param ref [String]
      # @param api_map [ApiMap]
      # @param skip [Array]
      # @return [Array<YARD::Tags::Tag>, nil]
      def resolve_reference ref, api_map, skip
        return nil if skip.include?(ref)
        skip.push ref
        parts = ref.split(/[\.#]/)
        if parts.first.empty?
          path = "#{namespace}#{ref}"
        else
          fqns = api_map.qualify(parts.first, namespace)
          return nil if fqns.nil?
          path = fqns + ref[parts.first.length] + parts.last
        end
        pins = api_map.get_path_pins(path)
        pins.each do |pin|
          params = pin.docstring.tags(:param)
          return params unless params.empty?
        end
        pins.each do |pin|
          params = see_reference(pin.docstring, api_map, skip)
          return params unless params.empty?
        end
        nil
      end
    end
  end
end
