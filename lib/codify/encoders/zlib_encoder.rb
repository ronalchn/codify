# Copyright (c) 2012 Ronald Ping Man Chan
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

require 'zlib'

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
