require_relative 'settlement_generator_helper'
require_relative 'point_of_interest'

module Settlements
  class Service < PointOfInterest
    attr_reader :hired_help_size

    def initialize(settlement, name: nil, quality: nil, settings: Configuration.new)
      @location_type = 'service'
      super(settlement, name: name, quality: quality, settings: settings)
      if @name =~ /Hired Help/
        @hired_help_size = roll_on_table('hired help size', 0, settlement.settlement_type)
        @name.concat(" (#{@hired_help_size['name']})")
      end
    end
  end
end