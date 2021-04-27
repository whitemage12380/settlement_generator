require_relative 'settlement_generator_helper'
require_relative 'point_of_interest'

class Service < PointOfInterest
  attr_reader :hired_help_size

  def initialize(settlement, name = nil)
    @location_type = 'service'
    super(settlement, name)
    if @name =~ /Hired Help/
      @hired_help_size = roll_on_table('hired_help_size', 0, settlement.settlement_type)
      @name.concat(" (#{@hired_help_size['name']})")
    end
  end

  def to_h()
    {name: @name, description: @description, quality: @quality['name'], hired_help_size: @hired_help_size}
  end
end