# Copyright (c) 2012 Ronald Ping Man Chan
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

module Codify
  module Encoders
    class DigestEncoder < AbstractEncoder
      def encode data
        algorithm = options(:algorithm) || :sha512
        OpenSSL::Digest.digest(algorithm.to_s, data)
      end

      def self.algorithms
        # [:mdc2] # disabled in many Linux distributions
        [:dss1, :md2, :md4, :md5, :ripemd160, :sha, :sha1, :sha224, :sha256, :sha384, :sha512]
      end
    end
  end
end
