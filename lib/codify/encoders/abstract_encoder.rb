module Codify
  module Encoders
    class AbstractEncoder
      def encode data, options = {}
        raise NotImplemented, "Error: #{self.name}.encode not implemented!"
      end
      def decodes?
        self.respond_to?(:decode)
      end
    end
  end
end
