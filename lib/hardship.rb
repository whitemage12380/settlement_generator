require_relative 'settlement_generator_helper'

class Hardship
  include SettlementGeneratorHelper

  attr_reader :type, :outcome, :name, :description

  def initialize(settlement_type = 'village')
    @type = roll_on_table('hardship type', 0, settlement_type, false)
    @name = @type['name']
    @description = @type['description']
    @outcome = roll_on_table('hardship outcome', 0, settlement_type, false)
    @outcome['modifier'] = @outcome['modifier'].to_i
    log "Added hardship: #{@type['name']} (#{modifiers_string})"
  end

  def modifiers_string()
    return @type['modified attributes']
      .collect { |table| "#{table} #{@outcome['modifier'].signed}" }
      .join(", ")
  end

  def print()
    puts @type['name']
    puts "  #{@type['description']}"
    puts "  Suffered #{@outcome['name'].downcase} (#{modifiers_string})."
  end
end