require_relative 'settlement_generator_helper'
require_relative 'owner'
require_relative 'family'

class PointOfInterest
  include SettlementGeneratorHelper
  attr_reader :name, :title, :description, :quality, :owners, :owner_group_title

  def initialize(settlement, name = nil, quality = nil) # TODO: Allow a generic shop or service that gets a generic name
    @location_type = 'location' if @location_type.nil?
    if name.nil?
      # The name roll table is in the individual settlement directory, the location content is in names/locations.yaml
      result = roll_on_table(@location_type + "s", 0, settlement.settlement_type, false)
      if result['special'] == 'reroll'
        append_name = " (#{result['name']})"
        append_description = " #{result['description']}"
        tries = 0
        while result['special'] == 'reroll'
          result = roll_on_table(@location_type + "s", 0, settlement.settlement_type, false)
          tries += 1
          raise "Rolled a 'reroll' option too many times" if tries >= 10
        end
      end
      name = result['name']
    end
    table = read_table('locations', 'names').select { |entry| entry['name'].downcase == name.downcase }.first
    @name = name + (append_name ? append_name : '')
    @owners = generate_owners(settlement.all_tables_hash['demographics'])
    @names = table.fetch('names', {}) unless table.nil?
    @title = generate_title()
    @description = (table['description'] + (append_description ? append_description : '')) unless table.nil?
    if table_exist?('quality', settlement.settlement_type)
      if quality.nil?
        @quality = roll_on_table('quality', settlement.modifiers['quality'], settlement.settlement_type, false)
      else
        @quality = read_table('quality', settlement.settlement_type).select{|q|q['name'] == quality}.first
      end
    end
    quality_str = @quality.nil? ? '' : " (#{@quality['name']})"
    log "Added #{@location_type}: #{@name.pretty}#{quality_str}"
  end

  def generate_title()
    title_template = roll_on_table('location_names', 0, 'names', false)['name']
    return title_template.gsub(/\{[^}]*\}/) { |elem_str|
      elem = elem_str[1...-1]
      elem_plural = "#{elem}s"
      case elem
      when 'adjective', 'noun'
        if @names.nil?
          location_word_chance = 0
        else
          location_word_chance = @names.fetch("location_#{elem}_chance",
                                 $configuration['locations'].fetch("location_#{elem}_chance", 0.5))
        end
        if rand() < location_word_chance and @names.has_key? elem_plural
          weighted_random(@names[elem_plural])
        else
          roll_on_table(elem_plural, 0, 'names', false)
        end
      when 'location'
        if @names.nil?
          synonym_chance = 0
        else
          synonym_chance = @names.fetch("synonym_chance",
                           $configuration['locations'].fetch("synonym_chance", 0.5))
        end
        if rand() < synonym_chance and @names.has_key? 'synonyms'
          weighted_random(@names['synonyms'])
        else
          (@names ? @names : {}).fetch('name', @name)
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
    puts "    Quality: #{@quality['name']}" unless @quality.nil?
    verbose "        #{@quality['description']}" unless @quality.nil?
    puts "    Owners: #{@owners.collect {|o| o.description }.join('\n            ')}" unless @owners.nil?
  end

  def to_h()
    {name: @name, description: @description, quality: @quality['name']}
  end
end