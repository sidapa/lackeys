# frozen_string_literal: true

module Lackeys
  # Lackeys::Registration is whats used to generate the hash
  # that Lackeys::Registry uses.
  class Registration
    CALLBACK_TYPES = [:before_save,
                      :after_save,
                      :before_create,
                      :after_create].freeze
    def initialize(source, dest)
      @source = source
      @dest = dest
      @exclusive_methods = []
      @multi_methods = []
      @validations = []

      @callbacks = {}
      CALLBACK_TYPES.each do |t|
        @callbacks[t] = []
      end
      @options = {}
      @return_wrappers = {}
    end

    def add_method(name, opts = {}, &block)
      if @exclusive_methods.include?(name) || @multi_methods.include?(name)
        raise "#{name} has already been registered"
      end

      opts = opts.dup
      target_array = multi_method_array?(opts.delete(:allow_multi) || false)
      target_array << name.to_sym

      @options["#{@source}##{name}"] = opts
      @return_wrappers["#{name}"] = block if block_given?

      nil
    end

    def add_validation(validation_name)
      if @validations.include?(validation_name)
        raise "#{validation_name} has already been registered as validation"
      end

      @validations << validation_name.to_sym
      nil
    end

    def add_callback(type, method_name)
      raise "#{type} not supported" unless CALLBACK_TYPES.include? type.to_sym

      if @callbacks[type.to_sym].include? method_name.to_sym
        raise "#{method_name} has already been registered"
      end

      @callbacks[type.to_sym] << method_name.to_sym
      nil
    end

    def to_h
      {
        source: @source,
        dest: @dest,
        exclusive_methods: @exclusive_methods,
        multi_methods: @multi_methods,
        validations: @validations,
        callbacks: @callbacks,
        options: @options,
        return_wrappers: @return_wrappers
      }
    end

    private

    def multi_method_array?(exclusive)
      exclusive ? @multi_methods : @exclusive_methods
    end
  end
end
