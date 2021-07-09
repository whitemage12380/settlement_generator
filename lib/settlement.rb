require_relative 'settlement_generator_helper'

class Settlement
  include SettlementGeneratorHelper

  attr_reader :settlement_type, :tables, :points_of_interest
  attr_accessor :name, :file

  def initialize(settlement_type, settings, configuration_path = nil)
    @settlement_type = settlement_type
    init_configuration(settings, configuration_path)
    @tables = settlement_type_tables()
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
    Hash[all_tables.collect { |table| [table['table_name'], table] }]
  end

  def table_value(table_name)
    all_tables_hash[table_name]['name']
  end

  def hardships() nil end
  def hardship_modifiers() [] end
  def hardship_modifiers_with_reason() [] end

  def generate_races(demographics = all_tables_hash['demographics'], table_name = @config.fetch('race_table', 'standard'))
    if configuration['races'].nil? or configuration['races'].empty?
      demographics.fetch('races', []).collect{|r|r['name']}.difference(['other']).each do |race_label|
        demographics['chosen_races'] = Hash.new if demographics['chosen_races'].nil?
        chosen_races = demographics['chosen_races']
        chosen_race = roll_race(chosen_races)
        log "Chose #{race_label} race: #{chosen_race.plural}"
        chosen_races[race_label] = chosen_race
        demographics['description'].sub!("#{race_label} race", chosen_race.plural)
      end
    else
      races = configuration['races'].take(3)
      race_labels = ['primary', 'secondary', 'tertiary'].take(races.size)
      demographics['races'] = race_labels.collect { |l| {'name' => l, 'weight' => 1} }
      demographics['chosen_races'] = configuration['races']
        .each_with_index.collect { |race_name, i| [race_labels[i], Race.new(race_name)] }.to_h
    end
  end

  def modifiers(tables = all_tables)
    return modifier_list(tables)
    .group_by { |m| m[0] } # Hash - keys are deduped table names, vals are arrays of [table, modifier] arrays
    .reject { |k,v| k.nil? } # Remove nil key (case of no modifiers)
    .transform_values  { |m|
      m.sum { |n| n[1] } # Get modifiers for a single table and sum them
    } # Hash - keys are deduped table names, vals are the final modifiers for those tables
  end

  # Gets all modifier arrays ([impacted table, modifier, impacting table]) for a given impacted table
  def table_modifiers(table, tables = all_tables)
    table = {'table_name' => table.to_s} if table.kind_of? String
    raise("Invalid table: #{table.to_s}") unless table.kind_of? Hash and table.has_key?('table_name')
    return modifier_list_with_reason(tables).select { |m| m[0] == table['table_name'] }
  end

  def table_modifiers_string(table, tables = all_tables)
    modifier_arrays = table_modifiers(table, tables).select { |tm| tm[1] != 0 }.collect { |tm|
      "#{tm[1].signed} from #{tm[2]}"
    }.join(", ")
  end

  # Returns a list of modifiers, where each modifier is an array of [table, modifier number]
  def modifier_list(tables = all_tables)
    return modifier_list_with_reason(tables).collect { |m| [m[0], m[1]] }
  end

  def modifier_list_with_reason(tables = all_tables)
    return (
      tables.collect { |table|
        table.fetch('modifiers', []).collect { |m|
          [m['table'], m['modifier'], table['table_name']]
        }
      } # Array of [table, modifier] arrays, overly nested, possibly lopsided
      .flatten(1) + ## Array of [name, modifier] arrays
        hardship_modifiers_with_reason() # Add modifiers from hardships in same format
    )
  end

  def restrictions(tables = all_tables)
    return restriction_list(tables)
      .reduce(Hash.new) { |memo, n|
        memo.merge(n) { |k, v1, v2| v1 + v2 }
      }
      .reject { |k,v| k.nil? } # Remove nil key (case of no restrictions)
    # Hash - keys are deduped table names, vals are the combined restrictions for that table
  end

  def restriction_list(tables = all_tables)
    return restriction_list_with_reason(tables).collect { |r| {r[0] => r[1]} }
  end

  def restriction_list_with_reason(tables = all_tables)
    return tables.collect { |table|
      table.fetch('restrictions', []).collect { |r|
        [r['table'], r['restrictions'], table['table_name']]
      }
    }.flatten(1)
  end

  def default_filename()
    "#{@settlement_type}_#{table_value('age').filename_style}_#{table_value('size').filename_style}"
  end

  def save(filename = (@file ? @file : default_filename), filepath = configuration['save_directory'])
    filename += ".yaml" unless filename =~ /\.yaml$/
    if filename =~ /^\//
      fullpath = filename
    else
      filepath = File.expand_path("#{File.dirname(__FILE__)}/../#{filepath}") unless filepath[0] == '/'
      fullpath = "#{filepath}/#{filename}"
    end
    @file = fullpath unless @file == fullpath
    log "Saving #{@settlement_type} to file: #{fullpath}"
    begin
      File.open(fullpath, "w") do |f|
        YAML::dump(self, f)
      end
    rescue SystemCallError => e
      log_error "Failed to save #{@settlement_type}:"
      log_error e.message
      return false
    end
    return true
  end

  def self.load(filename, filepath = Configuration.new['save_directory'])
    if filename =~ /^\/.*\.yaml$/
      fullpath = filename
    else
      filepath = File.expand_path("#{File.dirname(__FILE__)}/../#{filepath}") unless filepath[0] == '/'
      fullpath = "#{filepath}/#{filename}.yaml"
    end
    log "Loading settlement from file: #{fullpath}"
    settlement = nil
    File.open(fullpath, "r") do |f|
      settlement = YAML::load(f)
    end
    settlement.file = fullpath
    return settlement
  end
end