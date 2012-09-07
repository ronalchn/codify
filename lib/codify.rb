require "codify/version"
require "codify/model_additions"

require "codify/encoders.rb"

require "codify/model_adapters/abstract_adapter"
require "codify/model_adapters/active_record_adapter" if defined? ActiveRecord
# require "codify/model_adapters/datamapper_adapter" if defined? DataMapper
require "codify/railtie" if defined? Rails::Railtie

module Codify

end
