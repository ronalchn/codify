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
