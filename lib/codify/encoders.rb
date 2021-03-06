# Copyright (c) 2012 Ronald Ping Man Chan
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

require "codify/encoders/abstract_encoder"
require "codify/encoders/zlib_encoder"
require "codify/encoders/base64_encoder"
require "codify/encoders/digest_encoder"

module Codify
  module Encoders

    # A hash of hashes of the encoders that have been registered. The first level represents the
    # encoder type, the second level maps the symbol of an encoder, to the encoder class.
    @@registry = {:all => {}} # :nodoc:

    # Registers a symbol to an encoder class. This allows a symbol to be used to refer to the encoder
    # that should be used to encoding/decoding.
    #
    #   Codify::Encoders.register(symbol, encoder_class, type)
    #
    # The type parameter takes a single symbol, or array of symbols, representing the encoder type(s)
    # that the encoder can be classified under. All encoders are classified under :all, so this symbol
    # should not be passed in explicitly. If not specified, an empty array is assumed.
    #
    # Alternatively a block can be passed, which may represent a whole set of symbols. The block should
    # take a single symbol, and decide to return an encoder class (representing a successful match), or
    # nil (representing an unsuccessful match). For example:
    #
    #   Codify::Encoders.register(:compressor) do |symbol|
    #     { :zlib => Codify::Encoders::ZlibEncoder }[symbol] # returns nil if symbol not found
    #   end
    #
    # Where the same symbol is used within the same type for different encoders, precedence favours
    # encoders registered later. Additionally, all encoders registered via a block will have lower
    # precedence than encoders registered by a fixed symbol.
    #
    def self.register symbol, klass = nil, type = nil, &block
      raise ArgumentError, "wrong number of arguments (1 for 2)" if klass.nil? && !block_given?
      type = symbol if block_given?
      Array(type).map(&:to_sym).push(:all).each do |type|
        @@registry[type] ||= {} # ensure registry type initialized
        if block_given?
          (@@registry[type][0] ||= []).push(block)
        else
          @@registry[type][symbol.to_sym] = klass
        end
      end
    end

    # Finds the encoder class that a symbol is registered for. The encoder type can be set to give
    # precedence to a particular type of encoder that is searched first. This is relevant in case
    # of symbol collisions.
    #
    # If already a class or object which may be an Encoder (not a symbol), uses the input encoder.
    #
    # If it is a class, initialize the Encoder with input options
    #
    def self.init encoder, type = :all, auxiliary_inputs = nil, options = {} # :nodoc:
      return encoder if encoder.class < AbstractEncoder
      unless encoder.class == Class || encoder.class < AbstractEncoder
        symbol = encoder.to_sym
        @@registry[type] ||= {}
        encoder = nil
        unless type == :all
          encoder ||= @@registry[type][symbol]
          encoder ||= @@registry[type][0].reverse_each.reduce(nil) { |encoder,f| encoder || f[symbol] } if @@registry[type].has_key?(0)
        end
        encoder ||= @@registry[:all][symbol]
        encoder ||= @@registry[:all][0].reverse_each.reduce(nil) { |encoder,f| encoder || f[symbol] } if @@registry[:all].has_key?(0)
        raise KeyError, ":#{symbol} encoder of type :#{type || :all} not found" if encoder.nil?
      end
      encoder = encoder.new(options) if encoder.class === Class && encoder < AbstractEncoder
      encoder
    end

    def self.encode encoders, data, record = nil
      encoders.each do |encoder|
        encoder.record = record
        data = encoder.encode(data)
      end unless data.nil? # don't encode/decode if nil
      data
    end

    def self.decode encoders, data, record = nil
      encoders.reverse_each do |encoder|
        encoder.record = record
        data = encoder.decode(data)
      end unless data.nil? # don't encode/decode if nil
      data
    end

    # register default encoders
    register :none, AbstractEncoder # TODO: add a plaintext encoder

    # register compressors
    register :zlib, ZlibEncoder, :compressor

    # register plain encodings
    register :base64, Base64Encoder, :encoding
    register :strict_base64, Base64Encoder.new( :representation => :strict ), :encoding
    register :urlsafe_base64, Base64Encoder.new( :representation => :urlsafe ), :encoding

    # register digestors
    register :digestor do |symbol|
      next DigestEncoder.new(:algorithm => symbol) if DigestEncoder.algorithms.include? symbol
      nil
    end
  end
end
