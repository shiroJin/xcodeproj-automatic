# frozen_string_literal: true

module Solargraph
  class SourceMap
    module NodeProcessor
      class GvasgnNode < Base
        def process
          loc = get_node_location(node)
          pins.push Solargraph::Pin::GlobalVariable.new(
            location: loc,
            closure: region.closure,
            name: node.children[0].to_s,
            comments: comments_for(node),
            assignment: node.children[1]
          )
          process_children
        end
      end
    end
  end
end
