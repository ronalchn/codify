# Copyright (c) 2012 Ronald Ping Man Chan
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

module Codify
  module Encoders
    class AbstractEncoder
      # Assigns options to instance variable
      #
      def initialize options = {}
        @options = options.symbolize_keys
      end

      # Allow a record to be linked to this encoder (for procs)
      #
      def record= record
        @record = record
      end

      # Encoders derived from AbstractEncoder should re-implement encode and optionally
      # decode.
      #
      def encode data
        raise NotImplementedError, "Error: #{self.class.name}.encode not implemented!"
      end

      # Detects whether this encoder can be reversed
      #
      def decodes?
        respond_to?(:decode)
      end

      # Detects whether any options depend on record attributes. This has implications on the attribute interface.
      # If state information like keys or similar are not constant, then there cannot exist a class method
      # to encode or decode data (ie. encoding must be done on an instance).
      #
      def depends_on_record?
        @options.any? { |option| option.class === Proc || option.class === Symbol }
      end

      # Wrapper to easily use encoder for encoding, by automatically constructing one
      #
      def self.encode data, options = {}, record = nil
        encoder = new(options)
        encoder.record = record
        encoder.encode(data)
      end

      # Wrapper to easily use encoder for decoding, by automatically constructing one
      #
      def self.decode data, options = {}, record = nil
        encoder = new(options)
        encoder.record = record
        encoder.decode(data)
      end

      private
      # Reads the option - executing if it is a Proc
      #
      def options key
        value = @options[key]
        if value.class === Proc
          if value.arity == 0
            value = value.call
          else
            value = value.call(@record)
          end
        end
        value = @record.send(value) if value.class === Symbol
        value
      end

    end
  end
end
