# frozen_string_literal: true

module Lackeys
  # Lackeys::ObserverCache maps Obsevers to their instances
  class ObserverCache
    def initialize(calling_object)
      @cache = {}
      @calling_object = calling_object
    end

    def fetch(obs)
      return @cache[obs] if @cache[obs]

      @cache[obs] = obs.send(:new, @calling_object)
    end
  end
end
