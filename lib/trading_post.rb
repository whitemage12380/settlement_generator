require_relative 'settlement_generator_helper'

class TradingPost
  include SettlementGeneratorHelper
  attr_reader :settlement_type, :tables

  def initialize()
    @settlement_type = "trading_post"
    @config = $configuration[settlement_type]
    @tables = settlement_type_tables()
    all_tables.each do |table|
      table_name = table['table_name']
      table.merge!(roll_on_table(table_name, modifiers.fetch(table_name, 0)))
    end
    generate_races()
    # @tables.each_pair do |section_name, section_tables|
    #   section_tables.each do |table|
    #     table_name = table['table_name']
    #     table.merge!(roll_on_table(table_name, modifiers.fetch(table_name, 0)))
    #   end
    # end
  end

  def settlement_type_tables(settlement_type = @settlement_type)
    file_path = "#{Configuration.project_path}/data/settlement_types/#{settlement_type}.yaml"
    return read_yaml_file(file_path).transform_values { |section_tables|
      section_tables.collect { |table_name| {'table_name' => table_name} }
    }
  end

  def all_tables()
    @tables.values.flatten(1)
  end

  def all_tables_hash()
    puts Hash[all_tables.collect { |table| [table['table_name'], table] }]
    Hash[all_tables.collect { |table| [table['table_name'], table] }]
  end

  def modifiers(tables = @tables)
    #puts tables.values.flatten(1).to_s
    return tables.values.flatten(1).collect { |table|
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

  def print_trading_post()
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
  end
end