require_relative 'settlement_generator_helper'

class PointOfInterest
  include SettlementGeneratorHelper
  attr_reader :name, :description, :quality

  def initialize(settlement, name = nil)
    if name.nil?
      table = roll_on_table(@location_type + "s", 0, settlement.settlement_type, false)
    else
      table = read_table(@location_type + "s", settlement.settlement_type).select { |entry| entry['name'].downcase == name.downcase}.first
    end
    @name = table['name']
    @description = table['description']
    @quality = roll_on_table('quality', settlement.modifiers['quality'], settlement.settlement_type, false)
    log "Added #{@location_type}: #{@name.pretty} (#{@quality['name']})"
  end

  def print()
    puts @name
    puts "    #{@description}"
    puts "    #{@hired_help_size['description']}" unless @hired_help_size.nil?
    puts "    Quality: #{@quality['name']}"
    verbose "        #{@quality['description']}"
  end

  def to_h()
    {name: @name, description: @description, quality: @quality['name']}
  end
end