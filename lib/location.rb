require_relative 'settlement_generator_helper'
require_relative 'point_of_interest'

class Location < PointOfInterest
  attr_reader :hired_help_size

  def initialize(settlement, name = nil)
    @location_type = 'other location'
    super(settlement, name)
  end
end