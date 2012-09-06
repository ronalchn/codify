module Encapsulator
  module ActiveRecordAdditions

    def self.included(base)
      base.extend ClassMethods
    end

    module ClassMethods
      def compress_attribute attribute_name, options = {}
        attribute_name = attribute_name.to_sym
        compressed_attribute_name = "compressed_#{attribute_name}".to_sym
        uncompressed_var = "@_uncompressed_#{attribute_name}".to_sym
        old_uncompressed_var = "@_old_uncompressed_#{attribute_name}".to_sym

        options = { :level => Zlib::DEFAULT_COMPRESSION }.merge(options.symbolize_keys)

        has_uncompressed = self.attribute_names.include? attribute_name.to_s # check if (legacy) uncompressed attribute still exists

        define_method attribute_name do # override where to read it from
          value = self.instance_variable_get uncompressed_var
          if value.nil? # if uninitialized
            compressed_value = read_attribute(compressed_attribute_name)
            if !compressed_value.blank?
              value = Zlib::Inflate.inflate(compressed_value)
            elsif has_uncompressed
              value = read_attribute(attribute_name)
            end
            instance_variable_set uncompressed_var, value # initialize
          end
          value
        end

        define_method "#{attribute_name}=".to_sym do |value|
          compressed_value = Zlib::Deflate.deflate(value,options[:level]) # depends on compression option
          if !self.send("#{compressed_attribute_name}_changed?") # implement a little bit of ActiveModel::Dirty on uncompressed variable (for caching)
            self.instance_variable_set(old_uncompressed_var, self.instance_variable_get(uncompressed_var))
          end
          self.send :write_attribute, "compressed_#{attribute_name}", compressed_value
          self.instance_variable_set uncompressed_var, value # save a copy of the uncompressed value
        end

        define_method "#{attribute_name}_changed?".to_sym do
          self.send("#{compressed_attribute_name}_changed?")
        end

        define_method "#{attribute_name}_was".to_sym do # use cached old uncompressed variable if available
          self.instance_variable_get(old_uncompressed_var) || begin
            compressed_value = self.send("#{compressed_attribute_name}_was")
            next (has_uncompressed ? read_attribute(attribute_name) : nil) if compressed_value.blank?
            Zlib::Inflate.inflate(compressed_value)
          end
        end

        define_method "#{attribute_name}_change".to_sym do
          self.send("#{compressed_attribute_name}_changed?") ? [self.send("#{attribute_name}_was"),self.send("#{attribute_name}")] : nil
        end

        define_method "#{attribute_name}?".to_sym do
          value = self.send attribute_name
          value && !value.blank?
        end

        self.before_save do |record|
          # if writing a new compressed value, clear uncompressed value if necessary
          record.send(:write_attribute, attribute_name, "") if has_uncompressed && record.send("compressed_#{attribute_name}_changed?")
          true
        end

        define_method "compressed_#{attribute_name}=".to_sym do |value| # don't let users set compressed value manually (because it is dangerous)
          raise NoMethodError, "undefined method 'compressed_#{attribute_name}=' for #{self}"
        end
      end
    end
  end
end

