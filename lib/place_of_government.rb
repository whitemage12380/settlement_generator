require_relative 'settlement_generator_helper'
require_relative 'point_of_interest'

class PlaceOfGovernment < PointOfInterest

  def initialize(settlement_type, name = nil)
    settlement_type = settlement_type.settlement_type if settlement_type.kind_of? Settlement
    if name.nil?
      result = roll_on_table('places of government', 0, settlement_type, false)
    else
      result = read_table('places of government', settlement_type).select{|l|l['name'] == name}.first
    end
    @name = result['name']
    @description = result['description']
    log "Added place of government: #{@name}"
  end
end