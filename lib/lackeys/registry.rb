# frozen_string_literal: true

module Lackeys
  # Keeps track of object registries. Allows objects to register themselves
  # as listeners to events of another object
  class Registry
    CALLBACK_TYPES = [:before_save,
                      :after_save,
                      :before_create,
                      :after_create].freeze

    @registered_methods = {}
    @validations = {}
    @callbacks = {}

    CALLBACK_TYPES.each { |t| @callbacks[t] = {} }

    def self.add(registration)
      reg_hash = registration.to_h
      load_exclusive_methods(reg_hash)
      load_multi_methods(reg_hash)
      load_validations(reg_hash)
      load_callbacks(reg_hash)
      nil
    end

    def self.method?(method_name)
      @registered_methods.keys.include? method_name.to_sym
    end

    def self.call(method_name, calling_obj, *args)
      method_name = method_name.to_sym
      raise "#{method_name} has not been registered" unless method? method_name
      return_values = []
      @registered_methods[method_name][:observers].each do |obs|
        return_values << obs.send(method_name, calling_obj, *args)
      end

      return nil if return_values.empty?
      return_values.size > 1 ? return_values : return_values.first
    end

    def self.register(source)
      raise 'Registry#register requires a block' unless block_given?

      registration = Lackeys::Registration.new(source)
      yield registration

      add registration
    end

    def self.load_exclusive_methods(source_hash)
      source_hash[:exclusive_methods].each do |m|
        entry = @registered_methods.fetch(m, multi: false, observers: [])

        if entry[:observers].size > 0
          raise "#{m} has already been registered"
        end

        entry[:observers] << source_hash[:source]

        @registered_methods[m] = entry
      end
    end

    def self.load_multi_methods(source_hash)
      source_hash[:multi_methods].each do |m|
        entry = @registered_methods.fetch(m, multi: true, observers: [])

        if !entry[:multi] && entry[:observers].size > 0
          raise "#{m} has already been registered"
        end

        entry[:observers] << source_hash[:source]

        @registered_methods[m] = entry
      end
    end

    def self.load_validations(source_hash)
      source_hash[:validations].each do |m|
        existing_entry = @validations.fetch(m) { { observers: [] } }

        if existing_entry[:observers].include? source_hash[:source]
          raise "#{m} has already been registered"
        end

        existing_entry[:observers] << source_hash[:source]

        @validations[m] = existing_entry
      end
    end

    def self.load_callbacks(source_hash)
      source_hash[:callbacks].keys.each do |key|
        source_hash[:callbacks][key].each do |m|
          entry = @callbacks[key].fetch(m) { { observers: [] } }

          if entry[:observers].include? source_hash[:source]
            raise "#{m} has already been registered"
          end

          entry[:observers] << source_hash[:source]

          @callbacks[key][m] = entry
        end
      end
    end

    private_class_method :load_exclusive_methods,
                         :load_multi_methods,
                         :load_validations,
                         :load_callbacks
  end
end
