require_relative 'settlement_generator_helper'
require_relative 'settlement'
require_relative 'shop'
require_relative 'service'
require_relative 'place_of_worship'

class TradingPost < Settlement


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

  def generate_points_of_interest()
    @points_of_interest = Hash.new
    {'shops' => Shop, 'services' => Service}.each_pair do |poi_type, poi_class|
      modifier = modifiers.fetch(poi_type, 0)
      poi_count = roll(@config[poi_type], modifier)
      modifier_str = " (#{modifier.signed})" unless modifier == 0
      log "Adding #{poi_count} #{poi_type}#{modifier_str}"
      @points_of_interest[poi_type] = @config.fetch("default_#{poi_type}", []).collect { |poi_name| poi_class.new(self, poi_name) }
      @points_of_interest[poi_type].concat(Array.new(poi_count) { poi_class.new(self) })
    end
    if rand() < @config['place_of_worship_chance'].to_f
      @points_of_interest['place of worship'] = PlaceOfWorship.new(@settlement_type)
    end
  end

  def shops()
    @points_of_interest.fetch('shops', []).sort_by { |s| s.name }
  end

  def services()
    @points_of_interest.fetch('services', []).sort_by { |s| s.name }
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