require_relative 'settlement_generator_helper'
require_relative 'owner'
require_relative 'family'

class PointOfInterest
  include SettlementGeneratorHelper
  attr_reader :name, :title, :description, :quality, :owners, :owner_group_title

  def initialize(settlement, name = nil)
    if name.nil?
      table = roll_on_table(@location_type + "s", 0, settlement.settlement_type, false)
    else
      table = read_table(@location_type + "s", settlement.settlement_type).select { |entry| entry['name'].downcase == name.downcase}.first
    end
    @name = table['name']
    @owners = generate_owners(settlement.all_tables_hash['demographics'])
    @names = table.fetch('names', {})
    @title = generate_title()
    @description = table['description']
    @quality = roll_on_table('quality', settlement.modifiers['quality'], settlement.settlement_type, false)
    log "Added #{@location_type}: #{@name.pretty} (#{@quality['name']})"
  end

  def generate_title()
    title_template = roll_on_table('location_names', 0, 'names', false)['name']
    return title_template.gsub(/\{[^}]*\}/) { |elem_str|
      elem = elem_str[1...-1]
      elem_plural = "#{elem}s"
      case elem
      when 'adjective', 'noun'
        location_word_chance = @names.fetch("location_#{elem}_chance",
                               $configuration['locations'].fetch("location_#{elem}_chance", 0.5))
        if rand() < location_word_chance and @names.has_key? elem_plural
          weighted_random(@names[elem_plural])
        else
          roll_on_table(elem_plural, 0, 'names', false)
        end
      when 'location'
        synonym_chance = @names.fetch("synonym_chance",
                         $configuration['locations'].fetch("synonym_chance", 0.5))
        if rand() < synonym_chance and @names.has_key? 'synonyms'
          weighted_random(@names['synonyms'])
        else
          @names.fetch('name', @name)
        end
      when 'individual'
        raise "Person names not supported in location names yet!"
      when 'family'
        raise "Family names not supported in location names yet!"
      else
        raise "Incompatible template element: #{elem}"
      end
    }
  end

  def generate_owners(demographics)
    owner_strategy = roll_on_table('location_owners', 0, 'names', true)
    chosen_owners = Array.new (owner_strategy['adults']) {
      Owner.new(demographics)
    }
    return chosen_owners
  end

  def print()
    puts @title unless @title.nil?
    puts @name if @title.nil? or not @title.include? @name
    puts "    #{@description}"
    puts "    #{@hired_help_size['description']}" unless @hired_help_size.nil?
    puts "    Quality: #{@quality['name']}"
    verbose "        #{@quality['description']}"
    puts "    Owners: #{@owners.collect {|o| o.description }.join('\n            ')}"
  end

  def to_h()
    {name: @name, description: @description, quality: @quality['name']}
  end
end