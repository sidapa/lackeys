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

    def valid?(context = nil)
      validations = registry.send(:validations)
      observer_cache = registry.send(:observer_cache)
      validations.keys.each do |method_name|
        validations[method_name][:observers].each do |obs|
          cached_obs = observer_cache.fetch(obs)
          cached_obs.send(method_name)
        end
      end
      [self.errors.empty?, super(context)].all?
    end

    def method_missing(method_name, *args, &block)
      if registry.method? method_name
        registry.call method_name, *args
      else
        super
      end
    end

    #######################
    # Development methods #
    #######################
    def who_has?(method_name)
      return nil unless respond_to?(method_name)
      res = registry.method?(method_name, true)
      if res.nil?
        { klass: self.class, location: self.class.instance_method(method_name.to_sym).source_location.join(":") }
      else
        final = Array(res).map do |r|
          { klass: r, location: r.instance_method(method_name.to_sym).source_location.join(":") }
        end
        final.size == 1 ? final.first : final
      end
    end
  end
end