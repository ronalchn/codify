# Copyright (c) 2012 Ronald Ping Man Chan
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

require "codify/version"
require "codify/model_additions"

require "codify/encoders.rb"

require "codify/model_adapters/abstract_adapter"
require "codify/model_adapters/active_record_adapter" if defined? ActiveRecord
# require "codify/model_adapters/datamapper_adapter" if defined? DataMapper
require "codify/railtie" if defined? Rails::Railtie

module Codify

end
