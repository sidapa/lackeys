# frozen_string_literal: true

module Lackeys
  # Keeps track of object registries. Allows objects to register themselves
  # as listeners to events of another object
  class Registry
    CALLBACK_TYPES = [:before_save,
                      :after_save,
                      :before_create,
                      :after_create].freeze

    @registry = {}

    def initialize(calling_object)
      @caller = calling_object
    end

    def self.add(registration)
      reg_hash = registration.to_h
      dest = reg_hash[:dest]
      dest_hash = @registry.fetch(dest) { default_object_hash }
      load_exclusive_methods(reg_hash, dest_hash)
      load_multi_methods(reg_hash, dest_hash)
      load_validations(reg_hash, dest_hash)
      load_callbacks(reg_hash, dest_hash)
      @registry[dest] = dest_hash
      nil
    end

    # Takes in 2 parameters: source and dest
    # source (Object): The current object that processes registered methods
    # dest (String): The name target object that will use the registry
    def self.register(source, dest)
      raise 'Registry#register requires a block' unless block_given?

      registration = Lackeys::Registration.new(source, dest.name.to_sym)
      yield registration

      add registration
    end

    def self.value_by_caller(dest)
      @registry.fetch(dest, {})
    end

    def self.load_exclusive_methods(source_hash, dest_hash)
      source_hash[:exclusive_methods].each do |m|
        entry = dest_hash[:registered_methods].fetch(m, multi: false, observers: [])

        if entry[:observers].size > 0
          raise "#{m} has already been registered"
        end

        entry[:observers] << source_hash[:source]

        dest_hash[:registered_methods][m] = entry
      end
    end

    def self.load_multi_methods(source_hash, dest_hash)
      source_hash[:multi_methods].each do |m|
        entry = dest_hash[:registered_methods].fetch(m, multi: true, observers: [], returners: [])

        if !entry[:multi] && entry[:observers].size > 0
          raise "#{m} has already been registered"
        end

        entry[:observers] << source_hash[:source]
        entry[:returners] << source_hash[:source] if source_hash[:options]["#{source_hash[:source]}##{m}"][:returner]

        dest_hash[:registered_methods][m] = entry
      end
    end

    def self.load_validations(source_hash, dest_hash)
      source_hash[:validations].each do |m|
        existing_entry = dest_hash[:validations].fetch(m) { { observers: [] } }

        if existing_entry[:observers].include? source_hash[:source]
          raise "#{m} has already been registered"
        end

        existing_entry[:observers] << source_hash[:source]

        dest_hash[:validations][m] = existing_entry
      end
    end

    def self.load_callbacks(source_hash, dest_hash)
      callbacks = dest_hash[:callbacks]

      source_hash[:callbacks].keys.each do |key|
        source_hash[:callbacks][key].each do |m|
          entry = callbacks[key].fetch(m) { { observers: [] } }

          if entry[:observers].include? source_hash[:source]
            raise "#{m} has already been registered"
          end

          entry[:observers] << source_hash[:source]

          callbacks[key][m] = entry
        end
      end
    end

    def self.default_object_hash
      callbacks = {}
      CALLBACK_TYPES.each { |t| callbacks[t] = {} }

      {
        registered_methods: {},
        validations: {},
        callbacks: callbacks,
        registry: {}
      }
    end

    private_class_method :load_exclusive_methods,
                         :load_multi_methods,
                         :load_validations,
                         :load_callbacks,
                         :default_object_hash

    def method?(method_name)
      value_hash.keys.include? method_name.to_sym
    end

    CALLBACK_TYPES.each do |t|
      define_method("call_#{t}_callbacks".to_sym) do
        callbacks[t].keys.each do |method_name|
          callbacks[t][method_name][:observers].each do |obs|
            cached_obs = observer_cache.fetch(obs)
            cached_obs.send(method_name)
          end
        end
      end
    end

    def call(method_name, *args, &block)
      method_name = method_name.to_sym
      raise "#{method_name} has not been registered" unless method? method_name
      return_values = {}
      commit_chain = []
      is_multi = value_hash[method_name][:multi]

      value_hash[method_name][:observers].each do |obs|
        cached_obs = observer_cache.fetch(obs)
        res = cached_obs.send(method_name, *args, &block)
        if is_multi
          commit_chain << cached_obs
        else
          return_values[cached_obs.class] = res
        end
      end

      returners = value_hash[method_name][:returners] || []

      commit_chain.each do |c|
        res = c.send(:commit)
        return_values[c.class] = res if returners.empty? || returners.include?(c.class)
      end

      return nil if return_values.empty?
      # If there is more than 1 return value, return the whole hash. Otherwise, return the value of the (only) key
      return_values.size > 1 ? return_values : return_values.first.last
    end

    private

    def caller_class_name
      @caller.class.name.to_sym
    end

    def value_hash
      @value_hash ||= self.class.value_by_caller(caller_class_name)[:registered_methods]
    end

    def callbacks
      @callbacks ||= self.class.value_by_caller(caller_class_name)[:callbacks]
    end

    def validations
      @validations ||= self.class.value_by_caller(caller_class_name)[:validations]
    end

    def observer_cache
      @observer_cache ||= ObserverCache.new(@caller)
    end
  end
end
