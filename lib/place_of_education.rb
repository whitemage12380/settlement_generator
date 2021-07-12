require_relative 'settlement_generator_helper'
require_relative 'point_of_interest'

module Settlements
  class PlaceOfEducation < PointOfInterest

    def initialize(settlement_type)
      settlement_type = settlement_type.settlement_type if settlement_type.kind_of? Settlement
      result = roll_on_table('places of education', 0, settlement_type, false)
      @name = result['name']
      @description = result['description']
      log "Added place of education: #{@name}"
    end
  end
end