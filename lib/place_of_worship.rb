require_relative 'settlement_generator_helper'
require_relative 'point_of_interest'

class PlaceOfWorship < PointOfInterest
  include SettlementGeneratorHelper
  attr_reader :alignment, :fervency, :size

  def initialize(settlement_type, modifiers = {})
    settlement_type = settlement_type.settlement_type if settlement_type.kind_of? Settlement
    @alignment = roll_on_table('alignment of the faith', modifiers.fetch('alignment', 0), settlement_type, false)['name']
    @fervency = roll_on_table('fervency of local following', modifiers.fetch('fervency', 0), settlement_type, false)
    @size = roll_on_table('place of worship size', modifiers.fetch('size', 0), settlement_type, false)
    log "Applying modifiers to place of worship rolls: #{modifiers.to_s.sub('=>', ': ').gsub('"', '')}" unless modifiers.nil? or modifiers == {}
    log "Added place of worship: #{@size['name']} (#{@alignment}, #{fervency['name']})"
  end

  def name()
    "Place of worship - #{size['name']}"
  end

  def print()
    puts "Place of worship - #{size['name']}"
    puts "    #{size['description']}"
    puts "Fervency of local following: #{@fervency['name']}"
    puts "    #{@fervency['description']}"
    puts "Alignment of the faith: #{@alignment}"
  end
end