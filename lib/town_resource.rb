module Settlements
  class TownResource
    include SettlementGeneratorHelper
    attr_reader :name, :description

    def initialize(settlement_type = 'town', farming_specialty = false)
      table = read_table('farms_and_resources', settlement_type)
      if farming_specialty == true
        mod, iter = 8, 0
        while mod > 0
          weight = table[0]['weight'].to_i
          minus = [mod, weight].min
          mod -= minus
          weight -= minus
          iter += 1
        end
      end
      result = weighted_random(table)
      @name = result['name']
      @description = result['description']
      log "Added town resource: #{@name}"
    end

    def print()
      puts @name
      puts "    #{@description}"
    end

    def to_h()
      return {'name' => @name, 'description' => @description}
    end
  end
end