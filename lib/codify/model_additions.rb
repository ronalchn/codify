# Copyright (c) 2012 Ronald Ping Man Chan
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

module Codify
  class ModelResource
    attr_accessor :write_attribute

    def initialize
      @read_callbacks = {}
      @write_callbacks = {}
      @set_attribute = {}
      @get_attribute = {}
      @register = {}
      @component = 0
      @shadowed_read_method = {}
      @protected_attributes = Set.new
    end

    def read_callbacks attr
      @read_callbacks[attr]
    end

    def write_callbacks attr
      @write_callbacks[attr]
    end

    def before(action, attr, &block)
      if action == :read
        (@read_callbacks[attr.to_sym] ||= []).push(block)
      elsif action == :write
        (@write_callbacks[attr.to_sym] ||= []).push(block)
      end
    end

    def get_component
      @component+=1
    end

    def link_attributes(setattr,getattr,component=nil,initial=false,&block)
      component = @component+=1 if component.nil?
      @set_attribute[setattr] ||= {}
      @set_attribute[setattr][getattr] = { :block => block, :index => component }
      @get_attribute[getattr] = block if initial
      component
    end

    def get_linked_attributes(attr)
      attrs = {}
      q = [attr]
      while !q.empty?
        more_attrs = {}
        q = q.map do |attr|
          (@set_attribute[attr] || {})
        end
        q = q.inject(&:merge).map do |getattr,data|
          if attrs.include?(data[:index])
            []
          else
            more_attrs[data[:index]] ||= {}
            more_attrs[data[:index]].merge!(getattr => data[:block])
            [getattr]
          end
        end.flatten.uniq
        attrs.merge! more_attrs
      end
      attrs
    end

    def set_attribute(attr)
      @set_attribute[attr] || {}
    end

    def initial_get_attribute
      @get_attribute.dup
    end

    def register(attr, type)
      @register[attr] = type
    end

    def register_default(attr, type)
      @register[attr] = type unless @register.has_key?(attr)
    end

    def registered_attributes
      @register
    end

    def shadowed_read_method(attr, method = nil)
      @shadowed_read_method[attr] = method unless method.nil?
      @shadowed_read_method[attr]
    end

    def protect_attribute(attr)
      @protected_attributes.add(attr)
    end

    def protected_attributes
      @protected_attributes
    end

  end
  class State
    def class_resource
      @class_resource
    end

    def initialize codify_class_resource
      @class_resource = codify_class_resource
      @get_attribute = @class_resource.initial_get_attribute # callbacks to run when getting an attribute
      @last_get_attribute = {} # callbacks which were last set for each component
      @changed_attributes = {}
      @old_get_attribute = {}
      @old_last_get_attribute = {}
    end

    def before_read(object, attr)
      callback = @get_attribute[attr]
      return true if callback.nil?
      yield(object.instance_exec(&callback))
      @get_attribute.delete(attr) # if no exception raised
      return true
    end

    def before_write(object, attr, value)
#      callbacks = @class_resource.write_callbacks(attr.to_sym)
#      return true if callbacks.nil?
#      callbacks.map { |callback| object.instance_exec(value,&callback) }
    end

    def attribute_set(object, attr, dirty_included = false)
      set_attribute = @class_resource.get_linked_attributes(attr)
      @get_attribute.delete(attr)
      @last_get_attribute.merge(set_attribute)
      set_attribute.values.inject(&:merge).each do |getattr,block|
        attribute_will_change!(object, getattr) if dirty_included
        @get_attribute[getattr] = block
      end
    end

    # methods for dirty support

    def before_read_was(object, attr)
      callback = @old_get_attribute[attr]
      return true if callback.nil?
      #yield(object.instance_exec('_was',&callback))
      @changed_attributes[attr] = object.instance_exec('_was',&callback)
      @old_get_attribute.delete(attr)
      return true
    end

    def clear_changed_attributes
      @old_last_get_attribute = @last_get_attribute.dup
      @old_get_attribute.clear
      @changed_attributes.clear
    end

    def clear_change(object, attr) # clears any recorded change in an attribute
      @old_get_attribute.delete(attr)
      @changed_attributes.delete(attr)
      object.instance_variable_get(:@changed_attributes).delete(attr)
    end

    def attribute_will_change!(object, attr)
      return if @old_get_attribute.has_key?(attr) || @changed_attributes.has_key?(attr)
      if @get_attribute.has_key? attr
        @old_get_attribute[attr] = @get_attribute[attr] # save lazy callback if value not yet calculated
      else
        begin
          value = object.send attr
          value = value.clone if value.duplicable?
        rescue TypeError, NoMethodError
        end
        @changed_attributes[attr] = value # otherwise save actual value
      end
    end

  end
  module ModelAdditions

    def self.included(base)
      class_resource = ModelResource.new
      base.send :class_variable_set, '@@codify', class_resource
      class_resource.write_attribute = base.instance_method(:write_attribute)
      base.extend ClassMethods
      base.send :include, InstanceMethods
    end

    module InstanceMethods
      def initialize *args
        @codify ||= Codify::State.new self.class.class_variable_get :@@codify
        super
        #@changed_attributes.extend :clear
      end

#      def read_attribute(attr)
#        @codify.before_read(self, attr, value)
##        @codify.get_callback_for_attribute(attr).tap do |callback|
##          if !callback.nil?
##            newvalue = instance_exec(&callback)
##            @@codify.write_attribute.bind(self).call(attr, newvalue) # calls write_attribute before it got overridden
##          end
##        end
#        super(attr, value)
#      end
#
#      def write_attribute(attr, value)
#        # callbacks for writing
#        super(attr, value)# if @@codify.before_write(self, attr, value)
#        @codify.attribute_set(attr)
#      end
    end

    module ClassMethods
      def define_attribute_methods
        super
        class_resource = self.class_variable_get :@@codify
        imethods = instance_methods
        dirty_included = self < ActiveModel::Dirty

        class_resource.registered_attributes.each do |attr,type|
          setattr = "#{attr}=".to_sym

          if (type == :accessor && !imethods.include?(attr.to_sym))
            attr_reader attr.to_sym
            define_method setattr do |value|
              if dirty_included
                @codify.attribute_will_change!(self, attr) if value != instance_variable_get("@#{attr}".to_sym)
                changed_attributes = @codify.instance_variable_get(:@changed_attributes)
                @codify.clear_change(self, attr) if changed_attributes.has_key?(attr) && changed_attributes[attr] == value
              end
              instance_variable_set "@#{attr}".to_sym, value
            end
          end
          if type == :shadow_attribute
            shadowed_read_method = instance_method attr # must remember this
            shadowed_write_method = instance_method setattr

            class_resource.shadowed_read_method(attr, shadowed_read_method)

            define_method attr.to_sym do
              value = shadowed_read_method.bind(self).call
              return value unless value.nil?
              instance_variable_get "@#{attr}".to_sym
            end
            define_method setattr do |value|
              if dirty_included
                @codify.attribute_will_change!(self, attr) if value != instance_variable_get("@#{attr}".to_sym)
              end
              instance_variable_set "@#{attr}".to_sym, value
              shadowed_write_method.bind(self).call(nil)
            end
          end

          read_method = instance_method attr
          write_method = instance_method setattr

          define_method attr do
            changed = send "#{attr}_changed?" if dirty_included
            @codify.before_read(self, attr) do |value|
              write_method.bind(self).call(value)
            end
            @codify.clear_change(self, attr) unless changed if dirty_included
            read_method.bind(self).call
          end

          define_method setattr do |value|
            @codify.before_write(self, attr, value)
            write_method.bind(self).call(value)
            @codify.attribute_set(self, attr, dirty_included)
          end

          if dirty_included
            attribute_was = "#{attr}_was".to_sym
            attribute_changed = "#{attr}_changed?".to_sym
            attribute_change = "#{attr}_change".to_sym

            was_method = imethods.include?(attribute_was) ? instance_method(attribute_was) : nil
            changed_method = imethods.include?(attribute_changed) ? instance_method(attribute_changed) : nil

            define_method attribute_was do
              changed_attributes = @codify.instance_variable_get(:@changed_attributes)
              @codify.before_read_was(self, attr)
              if changed_attributes.has_key? attr
                changed_attributes[attr]
              elsif type == :attribute
                was_method.bind(self).call
              else
                send attr # get value from current value
              end
            end

            define_method attribute_changed do
              return true if @codify.instance_variable_get(:@old_get_attribute).has_key?(attr)
              return true if @codify.instance_variable_get(:@changed_attributes).has_key?(attr)
              return changed_method.bind(self).call if type == :attribute
              return false
            end

            define_method attribute_change do
              [send(attribute_was),send(attr)] if send(attribute_changed)
            end
          end
        end

        class_resource.protected_attributes.each do |attr|
          define_method "#{attr}=" do |*args|
            raise NoMethodError, "undefined method '#{attr}=' for #{self}"
          end
        end

        after_initialize do |record|
        end

        after_find do |record|
          @codify ||= Codify::State.new class_resource
          class_resource.registered_attributes.select{|attr,type|type==:shadow_attribute}.each do |attr,type|
            @codify.attribute_set(self, attr, false) unless class_resource.shadowed_read_method(attr).bind(self).call.nil?
          end
        end
      end

      # Shadows an attribute name, to deprecate a database column over time. This is used when this attribute should be
      # a virtual attribute, but in some cases, contains an old value (with no corresponding encoded value).
      #
      # This causes an attribute only to be read from, but never persisted in the database. It will acquire a value of nil over time.
      # On write, it sets the database value to nil.
      #
      def attr_shadow attribute_name
        class_variable_get(:@@codify).register attribute_name, :shadow_attribute
      end

      def attr_compressor attribute_name, options = {}
        options = { :encoder => :zlib,
                    :prefix => "compressed_",
                    :verb => "compress", 
                    :reverse_verb => "uncompress",
                    :encoder_type => :compressor }.merge(options.symbolize_keys)
        attr_encoder attribute_name, options
      end

      def attr_digestor attribute_name, options = {}
        options = { :encoder => :sha512,
                    :prefix => "digested_",
                    :verb => "digest",
                    :encoder_type => :digestor }.merge(options.symbolize_keys)
        attr_encoder attribute_name, options
      end

      # Sets up an attribute which will automatically be encoded
      #
      # <tt>attr_encoder('attribute_name', options = {}) creates a virtual attribute <tt>attribute_name</tt> 
      # that encodes input data to <tt>encoded_attribute_name</tt>. If <tt>encoded_attribute_name</tt> is not a
      # database field, the encoded input will be saved to a virtual input.
      #
      # <tt>attr_encoder('attribute_name', 'auxiliary_input', ..., options = {})</tt> will use the auxiliary inputs
      # (2nd to 2nd to last arguments) for the purpose of additional inputs to the encoders. Because they are
      # auxiliary, calls to auxiliary_input will be intercepted, and cause a re-encoding of any data encoded.
      # 
      ## <tt>attr_encoder(['attribute1','attribute2'])</tt> will encode two separate fields into a single field.
      ## The encoded field will by default be named using 'attribute1', unless otherwise specified by the options.
      ## If multiple fields are being encoded, the first encoder must be able to accept multiple fields.
      #
      def attr_encoder input_attributes, *args
        options = args.last.class == Hash ? args.pop : {}
        options = { :encoder => :none,
                    :prefix => "encoded_",
                    :suffix => "",
                    :verb => "encode",
                    # :include_plaintext => false,
                    :protect_encoded_attribute => true, # protect encoded attribute from being directly written to
                    :reverse_verb => "decode" }.merge(options.symbolize_keys)

        args.reverse!
        auxiliary_inputs = args.empty? ? nil : args.pop
        raise ArgumentError, "wrong number of arguments(#{args.size} too many)" unless args.empty?

        # manage options, extract those required (the rest will be passed to individual encoders)
        encoder_type = options.delete(:encoder_type)
        encoders = Array(options.delete(:encoder))
        prefix = options.delete(:prefix)
        suffix = options.delete(:suffix)
        verb = options.delete(:verb)
        reverse_verb = options.delete(:reverse_verb)
        protect_encoded_attribute = options.delete(:protect_encoded_attribute)

        encoders.map! { |encoder| Encoders.init(encoder, encoder_type, auxiliary_inputs, options) }

        # get full list of auxiliary inputs
        auxiliary_inputs = encoders.map(&:auxiliary_keys).flatten.uniq

        # deal with extra inputs

        # some constant variables (for naming purposes)
        attribute_name = Array(input_attributes).first.to_sym
        encoded_attribute_name = options.has_key?(:attribute) ? options.delete(:attribute) : "#{prefix}#{attribute_name}#{suffix}".to_sym
        #unencoded_ivar = "@_un#{encoded_attribute_name}".to_sym
        #old_unencoded_ivar = "@_old_un#{encoded_attribute_name}".to_sym
        #is_decoded = "@_#{encoded_attribute_name}_is_decoded".to_sym
        #is_encoded = "@_#{encoded_attribute_name}_is_encoded".to_sym

        # flags
        #depends_on_record = encoders.any? { |encoder| encoder.depends_on_record? } # then no class method to encode this attribute
        reversible = encoders.all? { |encoder| encoder.decodes? } # then no reading of encoded attributes

        class_resource = class_variable_get :@@codify

        # ensure that the attributes used are registered
        (Array(input_attributes) + Array(encoded_attribute_name)).each do |attr|
          if attribute_names.include?(attr.to_s)
            class_resource.register_default attr.to_sym, :attribute
          else
            class_resource.register_default attr.to_sym, :accessor
          end
        end
        class_resource.protect_attribute(encoded_attribute_name) if protect_encoded_attribute

        component = class_resource.get_component

        if reversible
          class_resource.link_attributes(encoded_attribute_name,attribute_name,component,true) do |suffix| # initial = true (decode attribute from db)
            encoded_value = send [encoded_attribute_name,suffix].join
            Encoders.decode(encoders, encoded_value, self)
          end
        end

        class_resource.link_attributes(attribute_name,encoded_attribute_name,component) do |suffix|
          value = send [attribute_name,suffix].join
          Encoders.encode(encoders, value, self)
        end

#        define_method encoded_attribute_name do
#          if instance_variable_get is_encoded
#            if encoded_attribute_name_get.nil?
#              read_attribute(encoded_attribute_name)
#            else
#              encoded_attribute_name_get.bind(self).call
#            end
#          else
#            value = send attribute_name
#            return nil if value.nil? # if decoded exists
#            encoded_value = Encoders.encode(encoders, value, self)
#            if encoded_attribute_name_set.nil?
#              write_attribute(encoded_attribute_name,encoded_value)
#            else
#              encoded_attribute_name_set.bind(self).call encoded_value # allow dirty methods to see it
#            end
#            instance_variable_set is_encoded, true
#          end
#        end
#
#        define_method "#{attribute_name}=".to_sym do |value|
#          #encoded_value = Encoders.encode(encoders, value, self)
#          if exclude_plaintext && is_encoded && !send("#{encoded_attribute_name}_changed?") # cache decoded var for ActiveModel::Dirty
#            instance_variable_set(old_unencoded_ivar, instance_variable_get(unencoded_ivar))
#          end
#          #write_attribute(encoded_attribute_name, encoded_value)
#          write_attribute(attribute_name, value) if include_plaintext
#          instance_variable_set unencoded_ivar, value # save a copy of the unencoded value
#          instance_variable_set is_decoded, true
#          instance_variable_set is_encoded, false
#        end
#
#        %w{changed? was change ?}.each do |modifier| # intercept these to make sure encoding is done
#          method_name = "#{encoded_attribute_name}_#{modifier}"
#          define_method method_name do
#            send encoded_attribute_name # execute any lazily-deferred encoding
#            super()
#          end
#        end
#
#        if exclude_plaintext
#          define_method "#{attribute_name}_changed?".to_sym do
#            send("#{encoded_attribute_name}_changed?")
#          end
#          
#          define_method "#{attribute_name}_was".to_sym do # use cached old unencoded variable if available
#            instance_variable_get(old_unencoded_ivar) || begin
#              encoded_value = send("#{encoded_attribute_name}_was")
#              next (has_unencoded ? send("#{attribute_name}_was") : nil) if encoded_value.blank?
#              value = Encoders.decode(encoders, encoded_value, self)
#              instance_variable_set(old_unencoded_ivar, value) # cache what has been decoded
#            end
#          end if reversible # do not define method if cannot decode
#
#          define_method "#{attribute_name}_change".to_sym do
#            send("#{encoded_attribute_name}_changed?") ? [send("#{attribute_name}_was"), send(attribute_name)] : nil
#          end if reversible
#
#          define_method "#{attribute_name}?".to_sym do
#            if reversible
#              value = send attribute_name
#            else
#              value = send encoded_attribute_name
#            end
#            value && !value.blank?
#          end
#        end
#
        
        after_initialize do |record|
          #@codify ||= Codify::State.new self.class.class_variable_get :@@codify # appears to be a bug in rails causing this to run before initialize

          #unless send("#{attribute_name}_changed?")
          #  @codify.attribute_set(self, encoded_attribute_name) # trigger recalc on link tree
          #end
#          instance_variable_set is_decoded, false
#          instance_variable_set is_encoded, !send(encoded_attribute_name).nil?
#          instance_variable_set is_decoded, true if include_plaintext
#          if reversible && depends_on_record && exclude_plaintext
#            instance_variable_set old_unencoded_ivar, send(attribute_name)
#          end
        end
#
        before_save do |record|
          send attribute_name # if is db column
          send encoded_attribute_name # if is db column
          # if writing a new encoded value, clear unencoded value if necessary
          # write_attribute(attribute_name, "") if has_unencoded && record.send("#{encoded_attribute_name}_changed?") && exclude_plaintext
          
#
#          # re-encode if states could have changed, and encoding might depend on those states, will only be re-encoded
#          # if either:
#          # * reversible - hence the original value was eager decoded (even if the decoded value is blank)
#          # * or not blank - hence the value has been written to (and there is something to re-encode)
#          # WARNING: if users change the state in another before_save callback after this executes, inconsistent state
#          # might still result
#          instance_variable_set(is_encoded,false) if (depends_on_record && record.changed?)
#          send encoded_attribute_name # make sure encoded
#          true
        end

#
#        define_method "#{encoded_attribute_name}=".to_sym do |*args| # don't let users set encoded value manually (because it is dangerous)
#          raise NoMethodError, "undefined method '#{encoded_attribute_name}=' for #{self}"
#        end

        # define class methods
        (class << self; self; end).instance_eval do
          define_method [verb,attribute_name].join('_').to_sym do |data|
            Encoders.encode(encoders,data)
          end

          define_method [reverse_verb,attribute_name].join('_').to_sym do |data|
            Encoders.decode(encoders,data)
          end if reversible
        end# if !depends_on_record
      end
    end
  end
end

