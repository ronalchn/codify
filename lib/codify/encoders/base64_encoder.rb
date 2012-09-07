module Codify
  module Encoders
    class Base64Encoder < AbstractEncoder
      def encode data
        Base64.send method_name(options(:representation),:encode64), data
      end

      def decode data
        Base64.send method_name(options(:representation),:decode64), data
      end

      private
      def method_name representation, suffix
        ({ :strict => "strict_", :urlsafe => "urlsafe_" }[representation.try(&:to_sym)] || "") + "#{suffix}"
      end
    end
  end
end
