module Settlements
  class Race < String
    attr_reader :name, :plural

    def initialize(race_obj)
      case race_obj
      when Hash
        @name = race_obj['name']
        @plural = race_obj.fetch('plural', "#{race_obj['name']}s")
      when String
        @name = race_obj
      else
        raise "Cannot create a race based on object: #{race_obj}"
      end
      super @name
    end
  end
end