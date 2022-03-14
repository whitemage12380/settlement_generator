require_relative 'settlement_generator_helper'
require_relative 'point_of_interest'

module Settlements
  class Location < PointOfInterest
    attr_reader :hired_help_size

    def initialize(settlement, name: nil, settings: Configuration.new)
      @location_type = 'other location'
      super(settlement, name: name, settings: settings)
    end
  end
end