module Codify
  module ModelAdditions

    def self.included(base)
      base.extend ClassMethods
    end

    module ClassMethods
      def attr_compressor attribute_name, options = {}
        attr_encoder attribute_name, { :prefix => "compressed_" }.merge(options)
      end

      def attr_encoder attribute_name, options = {}
        options = { :encoder => Codify::Encoders::ZlibEncoder.new, :prefix => "encoded_", :suffix => "" }.merge(options.symbolize_keys)
        encoder = options.delete(:encoder)
        prefix = options.delete(:prefix)
        suffix = options.delete(:suffix)

        attribute_name = attribute_name.to_sym
        encoded_attribute_name = "#{prefix}#{attribute_name}#{suffix}".to_sym
        unencoded_ivar = "@_un#{prefix}#{attribute_name}#{suffix}".to_sym
        old_unencoded_ivar = "@_old_un#{prefix}#{attribute_name}#{suffix}".to_sym

        has_unencoded = self.attribute_names.include? attribute_name.to_s # check if (legacy) unencoded attribute still exists

        define_method attribute_name do # override where to read it from
          value = self.instance_variable_get unencoded_ivar
          if value.nil? # if uninitialized
            encoded_value = read_attribute(encoded_attribute_name)
            if !encoded_value.blank?
              # value = Zlib::Inflate.inflate(encoded_value)
              value = encoder.decode(encoded_value,options)
            elsif has_unencoded
              value = read_attribute(attribute_name)
            end
            instance_variable_set unencoded_ivar, value # initialize
          end
          value
        end

        define_method "#{attribute_name}=".to_sym do |value|
          encoded_value = encoder.encode(value,options)
          if !self.send("#{encoded_attribute_name}_changed?") # implement a little bit of ActiveModel::Dirty on unencoded variable (for caching)
            self.instance_variable_set(old_unencoded_ivar, self.instance_variable_get(unencoded_ivar))
          end
          self.send :write_attribute, encoded_attribute_name, encoded_value
          self.instance_variable_set unencoded_ivar, value # save a copy of the unencoded value
        end

        define_method "#{attribute_name}_changed?".to_sym do
          self.send("#{encoded_attribute_name}_changed?")
        end

        define_method "#{attribute_name}_was".to_sym do # use cached old unencoded variable if available
          self.instance_variable_get(old_unencoded_ivar) || begin
            encoded_value = self.send("#{encoded_attribute_name}_was")
            next (has_unencoded ? read_attribute(attribute_name) : nil) if encoded_value.blank?
            value = encoder.decode(encoded_value,options)
          end
        end

        define_method "#{attribute_name}_change".to_sym do
          self.send("#{encoded_attribute_name}_changed?") ? [self.send("#{attribute_name}_was"),self.send("#{attribute_name}")] : nil
        end

        define_method "#{attribute_name}?".to_sym do
          value = self.send attribute_name
          value && !value.blank?
        end

        self.before_save do |record|
          # if writing a new encoded value, clear unencoded value if necessary
          record.send(:write_attribute, attribute_name, "") if has_unencoded && record.send("#{encoded_attribute_name}_changed?")
          true
        end

        define_method "#{encoded_attribute_name}=".to_sym do |value| # don't let users set encoded value manually (because it is dangerous)
          raise NoMethodError, "undefined method '#{encoded_attribute_name}=' for #{self}"
        end
      end
    end
  end
end

