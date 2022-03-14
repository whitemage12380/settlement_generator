require_relative 'settlement_generator_helper'
require_relative 'point_of_interest'

module Settlements
  class Shop < PointOfInterest

    def initialize(settlement, name: nil, quality: nil, settings: Configuration.new)
      @location_type = 'shop'
      super(settlement, name: name, quality: quality, settings: settings)
    end
  end
end