require_relative 'settlement_generator_helper'
require_relative 'point_of_interest'

class Shop < PointOfInterest

  def initialize(settlement, name = nil, quality = nil)
    @location_type = 'shop'
    super(settlement, name, quality)
  end
end