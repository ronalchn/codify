module Codify
  module Encoders
    class ZlibEncoder < AbstractEncoder
      def encode data, options = {}
        options = { :level => Zlib::DEFAULT_COMPRESSION }.merge(options)

        deflator = Zlib::Deflate.new( options[:level] )
        # deflator.set_dictionary(options[:dictionary]) if options.has_key? :dictionary
        deflator.deflate(data.to_s, Zlib::FINISH)
      end
      def decode data, options = {}
        inflator = Zlib::Inflate.new
        inflator.inflate(data)
      end
    end
  end
end
