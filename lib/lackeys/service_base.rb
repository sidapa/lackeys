module Lackeys
  class ServiceBase
    def initialize(parent)
      initialize_internals
      @parent = parent
    end

    def initialize_internals; end

    def parent; @parent; end

    def commit
      raise NotImplementedError
    end
  end
end