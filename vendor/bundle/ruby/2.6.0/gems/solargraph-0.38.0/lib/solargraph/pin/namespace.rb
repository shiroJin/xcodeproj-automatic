# frozen_string_literal: true

module Solargraph
  module Pin
    class Namespace < Closure
      # @return [::Symbol] :public or :private
      attr_reader :visibility

      # @return [::Symbol] :class or :module
      attr_reader :type

      # @param type [Symbol] :class or :module
      # @param visibility [Symbol] :public or :private
      # @param gates [Array<String>]
      def initialize type: :class, visibility: :public, gates: [''], **splat
        # super(location, namespace, name, comments)
        super(splat)
        @type = type
        @visibility = visibility
        if name.start_with?('::')
          @name = name[2..-1]
          @closure = Solargraph::Pin::ROOT_PIN
        end
        @open_gates = gates
        if @open_gates.one? && @open_gates.first.empty? && @name.include?('::')
          # In this case, a chained namespace was opened (e.g., Foo::Bar)
          # but Foo does not exist.
          parts = @name.split('::')
          @name = parts.pop
          @closure = Pin::Namespace.new(name: parts.join('::'), gates: [parts.join('::')])
          @context = nil
        end
      end

      def namespace
        context.namespace
      end

      def full_context
        @full_context ||= ComplexType.try_parse("#{type.to_s.capitalize}<#{path}>")
      end

      def binder
        full_context
      end

      def scope
        context.scope
      end

      def completion_item_kind
        (type == :class ? LanguageServer::CompletionItemKinds::CLASS : LanguageServer::CompletionItemKinds::MODULE)
      end

      # @return [Integer]
      def symbol_kind
        (type == :class ? LanguageServer::SymbolKinds::CLASS : LanguageServer::SymbolKinds::MODULE)
      end

      def path
        @path ||= (namespace.empty? ? '' : "#{namespace}::") + name
      end

      def return_type
        @return_type ||= ComplexType.try_parse( (type == :class ? 'Class' : 'Module') + "<#{path}>" )
      end

      def domains
        @domains ||= []
      end

      def typify api_map
        return_type
      end

      def gates
        @gates ||= if path.empty?
          @open_gates
        else
          [path] + @open_gates
        end
      end
    end
  end
end
