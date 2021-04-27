require_relative 'settlement_generator_helper'
require_relative 'point_of_interest'

class Shop < PointOfInterest

  def initialize(settlement, name = nil)
    @location_type = 'shop'
    super(settlement, name)
  end
end