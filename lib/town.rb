require_relative 'settlement_generator_helper'
require_relative 'settlement'
require_relative 'point_of_interest'
require_relative 'place_of_worship'
require_relative 'place_of_gathering'
require_relative 'place_of_education'
require_relative 'place_of_government'
require_relative 'town_resource'
require_relative 'location'

class Town < Settlement
  attr_reader :farms_and_resources

  def initialize(log_level = nil)
    @log_level = log_level.nil? ? nil : log_level.upcase
    @settlement_type = "town"
    @config = $configuration.fetch(settlement_type, {})
    @tables = settlement_type_tables()
    all_tables.each do |table|
      table_name = table['table_name']
      case table_name
      when 'farms and resources'
        generate_farms_and_resources()
      else
        table.merge!(roll_on_table(table_name, modifiers.fetch(table_name, 0)))
      end
    end
    generate_races()
    generate_points_of_interest()
  end

  def generate_farms_and_resources()
    farms_and_resources_rolls = all_tables_hash['size']['farms_and_resources_rolls']
    farming_specialty = (all_tables_hash['specialty'].fetch('special', nil) == 'farming')
    roll_mod = farming_specialty ? 1 : 0
    @farms_and_resources = Array.new(farms_and_resources_rolls.to_i + roll_mod) {
      TownResource.new(@settlement_type, farming_specialty)
    }.reject { |tr| tr.name == 'None' }
  end

  def generate_points_of_interest()
    @points_of_interest = Hash.new
    
    # Default Locations
    log "Generating default locations"
    @points_of_interest.merge!(default_services()) { |k, v1, v2| v1 + v2 }
    @points_of_interest.merge!(default_shops()) { |k, v1, v2| v1 + v2 }
    # Free Locations
    log "Generating free locations"
    @points_of_interest.merge!(free_locations()) { |k, v1, v2| v1 + v2 }
    # Noncommercial Locations
    noncommercial_locations_count = all_tables_hash['size']['noncommercial_locations'].to_i
    log "Generating #{noncommercial_locations_count} non-commercial locations based on size #{all_tables_hash['size']['name']}"
    noncommercial_locations = Array.new(noncommercial_locations_count) {
      random_noncommercial_location()
    }.reduce(Hash.new) { |memo, n|
      memo.merge(n) { |k, v1, v2| v1 + v2 }
    }
    @points_of_interest.merge!(noncommercial_locations) { |k, v1, v2| v1 + v2 }
    # Commercial Locations
    commercial_locations_count = all_tables_hash['size']['commercial_locations'].to_i
    commercial_locations = {'shops' => [], 'services' => []}
    commercial_locations_count.times do
      case roll_on_table('shop_or_service')['name']
      when 'Shop'
        commercial_locations['shops'] << Shop.new(self)
      when 'Service'
        commercial_locations['services'] << Service.new(self)
      end
    end
    @points_of_interest.merge!(commercial_locations) { |k, v1, v2| v1 + v2 }
  end

  def default_services()
    {'services' => @config.fetch('default_services', [])
      .collect { |poi|
        if (poi == 'Inn') and not hospitality_quality.nil?
          log "Assigning quality to default inn due to hospitality specialty: #{hospitality_quality}"
          Service.new(self, poi, hospitality_quality)
        else
          Service.new(self, poi)
        end
      }
    }
  end

  def default_shops()
    {'shops' => @config.fetch('default_shops', [])
      .collect { |poi|
        Shop.new(self, poi)
      }
    }
  end

  def free_locations()
    # Tables that add free locations: Priority, Specialty, Leadership
    all_tables.collect { |t|
      log "Free location for #{t['table_name']} (#{t['name']})" if t.has_key?('locations')
      t.fetch('locations', [])
    }
      .flatten
      .collect { |location|
        case location
        when Hash
          new_town_location(location)
        when 'Non-Commercial Location'
          random_noncommercial_location()
        when /Place of/
          random_noncommercial_location(location)
        when 'Shop', 'Service'
          new_town_location(location)
        else
          log "Free location not yet supported: #{location}"
          nil
        end
      }
      .reject { |t| t.nil? }
      .reduce(Hash.new) { |memo, n|
        memo.merge(n) { |k, v1, v2| v1 + v2 }
      }
  end

  def random_noncommercial_location(type = roll_on_table('noncommercial_location_type')['name'])
    return new_town_location(type)
  end

  def new_town_location(type)
    if type.kind_of? Hash
      name = type['name']
      type = type['type']
    else
      name = nil
    end
    # Returns hash so the proper hash can be built without repeating this case statement
    case type
    when 'Place of Education'
      {'places of education' => [PlaceOfEducation.new(@settlement_type)]}
    when 'Place of Gathering'
      {'places of gathering'=> [PlaceOfGathering.new(@settlement_type)]}
    when 'Place of Government'
      {'places of government' => [PlaceOfGovernment.new(@settlement_type, name)]}
    when /Place of Worship/
      if type =~ /([-+]\d)/
        log "Adding #{$1} to place of worship size"
        modifiers = {'size' => $1.to_i}
      else
        modifiers = {}
      end
      {'places of worship' => [PlaceOfWorship.new(@settlement_type, modifiers)]}
    when 'Shop'
      {'shops' => [Shop.new(self, name)]}
    when 'Service'
      {'service' => [Service.new(self, name)]}
    else
      raise "Unsupported location: #{type}"
    end
  end

  def shops()
    @points_of_interest.fetch('shops', []).sort_by { |s| s.name }
  end

  def services()
    @points_of_interest.fetch('services', []).sort_by { |s| s.name }
  end

  def religious?()
    all_tables_hash['priority']['special'] == 'religious'
  end

  def hospitality_quality()
    if all_tables_hash['specialty']['special'] == 'hospitality'
      all_tables_hash['specialty']['inn_quality']
    else
      nil
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
    unless @farms_and_resources.empty?
      puts "------------------"
      puts "FARMS AND RESOURCES"
      puts "------------------"
      puts
      @farms_and_resources.each { |r| r.print(); puts}
    end
    ['places of education', 'places of gathering', 'places of government', 'places of worship',
     'shops', 'services'].each do |poi_type|
      unless @points_of_interest.fetch(poi_type, []).empty?
        puts "------------------"
        puts poi_type.gsub(/_/, ' ').upcase
        puts "------------------"
        puts
        @points_of_interest.fetch(poi_type, [])
          .sort_by { |s| s.name }
          .each { |poi| poi.print(); puts}
      end
    end
    # unless @points_of_interest.fetch('shops'.empty?
    #   puts "------------------"
    #   puts "SHOPS"
    #   puts "------------------"
    #   puts
    #   @points_of_interest['shops'].each { |poi| poi.print(); puts}
    # end
    # unless @points_of_interest['services'].empty?
    #   puts "------------------"
    #   puts "SERVICES"
    #   puts "------------------"
    #   puts
    #   @points_of_interest['services'].each { |poi| poi.print(); puts}
    # end
  end
end