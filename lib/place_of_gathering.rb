require_relative 'settlement_generator_helper'
require_relative 'point_of_interest'

class PlaceOfGathering < PointOfInterest

  def initialize(settlement_type)
    settlement_type = settlement_type.settlement_type if settlement_type.kind_of? Settlement
    result = roll_on_table('places of gathering', 0, settlement_type, false)
    @name = result['name']
    @description = result['description']
    log "Added place of gathering: #{@name}"
  end
end