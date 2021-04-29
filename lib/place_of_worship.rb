require_relative 'settlement_generator_helper'
require_relative 'point_of_interest'

class PlaceOfWorship < PointOfInterest
  include SettlementGeneratorHelper
  attr_reader :alignment, :fervency, :size

  def initialize(settlement_type)
    @alignment = roll_on_table('alignment of the faith', 0, settlement_type, false)['name']
    @fervency = roll_on_table('fervency of local following', 0, settlement_type, false)
    @size = roll_on_table('place of worship size', 0, settlement_type, false)
    log "Rolled place of worship: #{@size['name']} (#{@alignment}, #{fervency['name']})"
  end

  def print()
    puts "Place of worship - #{size['name']}"
    puts "    #{size['description']}"
    puts "Fervency of local following: #{@fervency['name']}"
    puts "    #{@fervency['description']}"
    puts "Alignment of the faith: #{@alignment}"
  end
end