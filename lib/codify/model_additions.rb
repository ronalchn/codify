# Copyright (c) 2012 Ronald Ping Man Chan
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

module Codify
  module ModelAdditions

    def self.included(base)
      base.extend ClassMethods
    end

    module ClassMethods
      def attr_compressor attribute_name, options = {}
        options = { :encoder => :zlib, :prefix => "compressed_", :verb => "compress", :reverse_verb => "uncompress", :encoder_type => :compressor }.merge(options.symbolize_keys)
        attr_encoder attribute_name, options
      end

      def attr_encoder attribute_name, options = {}
        options = { :encoder => :none, :prefix => "encoded_", :suffix => "", :verb => "encode", :reverse_verb => "decode" }.merge(options.symbolize_keys)
        # manage options, extract those required (the rest will be passed to individual encoders)
        encoder_type = options.delete(:encoder_type)
        encoders = Array(options.delete(:encoder))
        prefix = options.delete(:prefix)
        suffix = options.delete(:suffix)
        verb = options.delete(:verb)
        reverse_verb = options.delete(:reverse_verb)

        encoders.map! { |encoder| Encoders.find(encoder, encoder_type, options) }
        # give encoders a reference to the record if they require it
        encoders.each { |encoder| encoder.record = self if encoder.depends_on_record? }

        # some constant variables (for naming purposes)
        attribute_name = attribute_name.to_sym
        encoded_attribute_name = options.has_key?(:attribute) ? options.delete(:attribute) : "#{prefix}#{attribute_name}#{suffix}".to_sym
        unencoded_ivar = "@_un#{encoded_attribute_name}".to_sym
        old_unencoded_ivar = "@_old_un#{encoded_attribute_name}".to_sym

        # flags
        has_unencoded = attribute_names.include? attribute_name.to_s # check if (legacy) unencoded attribute still exists
        depends_on_record = encoders.any? { |encoder| encoder.depends_on_record? } # then no class method to encode this attribute
        reversible = encoders.all? { |encoder| encoder.decodes? } # then no reading of encoded attributes

        define_method attribute_name do # override where to read it from
          value = instance_variable_get unencoded_ivar
          if value.nil? # if uninitialized
            encoded_value = read_attribute(encoded_attribute_name)
            if reversible && !encoded_value.blank?
              value = Encoders.decode(encoders, encoded_value)
            elsif has_unencoded
              value = read_attribute(attribute_name)
            end
            instance_variable_set unencoded_ivar, value # initialize
          end
          value
        end

        define_method "#{attribute_name}=".to_sym do |value|
          encoded_value = Encoders.encode(encoders, value)
          if !send("#{encoded_attribute_name}_changed?") # implement a little bit of ActiveModel::Dirty on unencoded variable (for caching)
            instance_variable_set(old_unencoded_ivar, instance_variable_get(unencoded_ivar))
          end
          write_attribute(encoded_attribute_name, encoded_value)
          instance_variable_set unencoded_ivar, value # save a copy of the unencoded value
        end

        define_method "#{attribute_name}_changed?".to_sym do
          send("#{encoded_attribute_name}_changed?")
        end
        
        define_method "#{attribute_name}_was".to_sym do # use cached old unencoded variable if available
          instance_variable_get(old_unencoded_ivar) || begin
            encoded_value = send("#{encoded_attribute_name}_was")
            next (has_unencoded ? read_attribute(attribute_name) : nil) if encoded_value.blank?
            value = Encoders.decode(encoders, encoded_value)
            instance_variable_set(old_unencoded_ivar, value) # cache what has been decoded
          end
        end if reversible # do not define method if cannot decode

        define_method "#{attribute_name}_change".to_sym do
          send("#{encoded_attribute_name}_changed?") ? [send("#{attribute_name}_was"), send(attribute_name)] : nil
        end if reversible

        define_method "#{attribute_name}?".to_sym do
          if reversible
            value = send attribute_name
          else
            value = send encoded_attribute_name
          end
          value && !value.blank?
        end

        after_initialize do |record| # eager decoding attribute in case other record states change (affecting encoding)
          encoded_value = read_attribute(encoded_attribute_name)
          instance_variable_set unencoded_ivar, Encoders.decode(encoders, encoded_value) unless encoded_value.blank?
        end if reversible && depends_on_record

        before_save do |record|
          # if writing a new encoded value, clear unencoded value if necessary
          write_attribute(attribute_name, "") if has_unencoded && record.send("#{encoded_attribute_name}_changed?")

          # re-encode if states could have changed, and encoding might depend on those states
          # WARNING: if users change the state in another before_save callback after this executes, inconsistent state
          # might still result
          if depends_on_record && self.changed?
            value = send(attribute_name)
            write_attribute(encoded_attribute_name, Encoders.encode(encoders, value))
          end
          true
        end

        define_method "#{encoded_attribute_name}=".to_sym do |value| # don't let users set encoded value manually (because it is dangerous)
          raise NoMethodError, "undefined method '#{encoded_attribute_name}=' for #{self}"
        end

        # define class methods
        (class << self; self; end).instance_eval do
          define_method [verb,attribute_name].join('_').to_sym do |data|
            Encoders.encode(encoders,data)
          end

          define_method [reverse_verb,attribute_name].join('_').to_sym do |data|
            Encoders.decode(encoders,data)
          end
        end if !depends_on_record
      end
    end
  end
end

