module Codify
  module Encoders
    class ZlibEncoder < AbstractEncoder
      def encode data
        level = options(:level) || Zlib::DEFAULT_COMPRESSION

        deflator = Zlib::Deflate.new(level)
        # deflator.set_dictionary(options[:dictionary]) if options.has_key? :dictionary
        deflator.deflate(data.to_s, Zlib::FINISH)
      end

      def decode data
        inflator = Zlib::Inflate.new
        inflator.inflate(data)
      end
    end
  end
end
