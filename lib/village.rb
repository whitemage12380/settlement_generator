require_relative 'settlement_generator_helper'
require_relative 'settlement'
require_relative 'hardship'
require_relative 'point_of_interest'
require_relative 'place_of_worship'
require_relative 'place_of_gathering'
require_relative 'location'

class Village < Settlement
  attr_reader :hardships, :hardships_description

  def initialize(settings: {}, configuration_path: nil)
    super('village', settings, configuration_path)
    all_tables.each do |table|
      table_name = table['table_name']
      case table_name
      when 'hardships'
        generate_hardships()
      else
        table.merge!(roll_on_table(table_name, modifiers.fetch(table_name, 0)))
      end
    end
    generate_races()
    generate_points_of_interest()
  end

  def hardship_modifiers()
    return [] if @hardships.nil?
    return hardship_modifiers_with_reason.collect { |h| [h[0], h[1]] }
  end

  def hardship_modifiers_with_reason()
    return [] if @hardships.nil?
    return @hardships.collect { |hardship|
      hardship.type.fetch('modified attributes', []).collect { |table|
        [table, hardship.outcome['modifier'], hardship.name]
      }
    } # Array of [table, modifier] arrays, overly nested, possibly lopsided
    .flatten(1) # Array of [name, modifier] arrays
  end

  def generate_hardships(likelihood_modifier = modifiers.fetch('hardship_likelihood', 0))
    hardships_result = roll_on_table('hardship_likelihood', likelihood_modifier)
    hardships_count = hardships_result['hardships']
    @hardships_description = hardships_result['description']
    @hardships = Array.new(hardships_count) { Hardship.new() }
  end

  def generate_points_of_interest()
    roll_strings = all_tables_hash['size']['rolls'].collect{|r|[r['table'], r['roll']]}.to_h
    free_location_names = all_tables_hash['resources'].fetch('locations', [])
    @points_of_interest = Hash.new
    { 'places of worship' => PlaceOfWorship,
      'places of gathering' => PlaceOfGathering,
      'other locations' => Location
    }.each do |poi_type, poi_class|
      poi_count = roll(roll_strings[poi_type])
      log "Adding #{poi_count} #{poi_count > 1 ? poi_type : poi_type.sub(/s /, ' ').sub(/s$/, '')}"
      @points_of_interest[poi_type] = Array.new(poi_count) { poi_class.new(self) }
      if poi_type == 'other locations'
        log "Adding due to resources: #{free_location_names.join(", ")}"
        @points_of_interest[poi_type].concat(free_location_names.collect { |poi_name| puts poi_name; poi_class.new(self, poi_name) })
      end
    end
  end

  def print()
    puts @settlement_type.pretty
    puts
    puts
    @tables.each_pair do |section_name, section_tables|
      puts "------------------"
      puts section_name.upcase
      puts "------------------"
      puts
      section_tables.reject { |t| t['name'].nil? and t['description'].nil?  }.each do |table|
        puts "#{table['table_name'].pretty}: #{table['name']}"
        puts "    #{table['description']}"
        unless table_modifiers_string(table['table_name']).empty?
          puts "    (#{table_modifiers_string(table['table_name'])})"
        end
        puts
      end
    end
    puts "------------------"
    puts "HARDSHIPS"
    puts "------------------"
    puts
    puts @hardships_description
    puts
    @hardships.each { |hardship| hardship.print(); puts}
    unless @points_of_interest['places of worship'].empty?
      puts "------------------"
      puts "PLACES OF WORSHIP"
      puts "------------------"
      puts
      @points_of_interest['places of worship'].each { |poi| poi.print(); puts}
    end
    unless @points_of_interest['places of gathering'].empty?
      puts "------------------"
      puts "PLACES OF GATHERING"
      puts "------------------"
      puts
      @points_of_interest['places of gathering'].each { |poi| poi.print(); puts}
    end
    unless @points_of_interest['other locations'].empty?
      puts "------------------"
      puts "OTHER LOCATIONS"
      puts "------------------"
      puts
      @points_of_interest['other locations'].each { |poi| poi.print(); puts}
    end
  end

end