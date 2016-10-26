module Lackeys
  module RailsBase
    def self.included(base)
      base.class_eval do
        define_model_callbacks :save, :create

        Registration::CALLBACK_TYPES.each do |c|
          send(c, lambda { registry.send("call_#{c}_callbacks".to_sym) })
        end
      end
    end

    def registry
      @__registry ||= Registry.new(self)
    end

    def respond_to?(method_name, other_param = nil)
      registry.method?(method_name) || super(method_name, other_param)
    end

    def method_missing(method_name, *args, &block)
      if registry.method? method_name
        registry.call method_name, *args
      else
        super
      end
    end
  end
end