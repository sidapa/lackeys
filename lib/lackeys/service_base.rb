module Lackeys
  class ServiceBase
    def initialize(parent)
      @parent = parent
    end

    def parent; @parent; end

    def commit
      raise NotImplementedError
    end
  end
end