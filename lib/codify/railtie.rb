# Copyright (c) 2012 Ronald Ping Man Chan
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

module Codify
  class Railtie < ::Rails::Railtie
    initializer 'codify.model_additions' do
      ActiveSupport.on_load(:active_record) do
        include Codify::ModelAdditions
      end

      # initialize other persistent models

      # if defined? ::DataMapper
      #  ::DataMapper::Model.append_extensions(Codify::ModelAdditions)
      # end
    end
  end
end
