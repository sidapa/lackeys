module Lackeys
  module RailsBase
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