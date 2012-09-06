module Encapsulator
  class Railtie < ::Rails::Railtie
    initializer 'encapsulator.active_record' do
      ActiveSupport.on_load(:active_record) do
        include Encapsulator::ActiveRecordAdditions
      end
    end
  end
end
