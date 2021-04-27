require_relative 'settlement_generator_helper'
require_relative 'shop'
require_relative 'service'
require_relative 'place_of_worship'

class TradingPost
  include SettlementGeneratorHelper
  attr_reader :settlement_type, :tables, :points_of_interest

  def initialize()
    @settlement_type = "trading_post"
    @config = $configuration[settlement_type]
    @tables = settlement_type_tables()
    all_tables.each do |table|
      table_name = table['table_name']
      table.merge!(roll_on_table(table_name, modifiers.fetch(table_name, 0)))
    end
    generate_races()
    generate_points_of_interest()
  end

  def settlement_type_tables(settlement_type = @settlement_type)
    file_path = "#{Configuration.project_path}/data/settlement_types/#{settlement_type}.yaml"
    return read_yaml_file(file_path).transform_values { |section_tables|
      section_tables.collect { |table_name| {'table_name' => table_name} }
    }
  end

  def generate_points_of_interest()
    @points_of_interest = Hash.new
    {'shops' => Shop, 'services' => Service}.each_pair do |poi_type, poi_class|
      poi_count = roll(@config[poi_type])
      @points_of_interest[poi_type] = @config.fetch("default_#{poi_type}", []).collect { |poi_name| poi_class.new(self, poi_name) }
      @points_of_interest[poi_type].concat(Array.new(poi_count) { poi_class.new(self) })
    end
    if rand() < @config['place_of_worship_chance'].to_f
      @points_of_interest['place of worship'] = PlaceOfWorship.new(@settlement_type)
    end
  end

  def all_tables()
    @tables.values.flatten(1)
  end

  def all_tables_hash()
    Hash[all_tables.collect { |table| [table['table_name'], table] }]
  end

  def table_value(table_name)
    all_tables_hash[table_name]['name']
  end

  def shops()
    @points_of_interest.fetch('shops', []).sort_by { |s| s.name }
  end

  def services()
    @points_of_interest.fetch('services', []).sort_by { |s| s.name }
  end

  def modifiers(tables = @tables)
    return all_tables.collect { |table|
      table.fetch('modifiers', []).collect { |m|
        [m['table'], m['modifier']]
      }
    } # Array of [table, modifier] arrays, overly nested, possibly lopsided
    .flatten(1) ## Array of [name, modifier] arrays
    .group_by { |m| m[0] } # Hash - keys are deduped table names, vals are arrays of [table, modifier] arrays
    .reject { |k,v| k.nil? } # Remove nil key (case of no modifiers)
    .transform_values  { |m|
      m.sum { |n| n[1] } # Get modifiers for a single table and sum them
    } # Hash - keys are deduped table names, vals are the final modifiers for those tables
  end

  def default_filename()
    "#{@settlement_type}_#{table_value('age').filename_style}_#{table_value('size').filename_style}"
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
      section_tables.each do |table|
        puts "#{table['table_name'].pretty}: #{table['name']}"
        puts "    #{table['description']}"
        puts
      end
    end
    puts "------------------"
    puts "SHOPS"
    puts "------------------"
    puts
    shops.each { |shop| shop.print(); puts}
    puts "------------------"
    puts "SERVICES"
    puts "------------------"
    puts
    services.each { |service| service.print(); puts}
    unless @points_of_interest['place of worship'].nil?
      puts "------------------"
      puts "PLACE OF WORSHIP"
      puts "------------------"
      puts
      @points_of_interest['place of worship'].print()
    end
  end
end