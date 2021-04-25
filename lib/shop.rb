require_relative 'settlement_generator_helper'

class Shop < PointOfInterest

  def initialize(name = nil)
    @location_type = 'shop'
    super(name)
  end
end