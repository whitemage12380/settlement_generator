require 'date'
require_relative 'settlement_generator_helper'

module Settlements
  class Settlement
    include SettlementGeneratorHelper

    attr_reader :settlement_type, :tables, :points_of_interest, :created_at, :modified_at

    def initialize(settlement_type, settings, configuration_path = nil, name = nil)
      @name = name.pretty unless name.nil?
      @settlement_type = settlement_type
      init_configuration(settings, configuration_path)
      @tables = settlement_type_tables()
      @created_at = DateTime.now()
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

    def rename(new_name)
      if new_name.pretty == name
        log_warning "Cannot rename #{@settlement_type} to the same name"
        return
      end
      log "Renaming #{name} to #{new_name}"
      new_filename = "#{new_name.underscore}.yaml"
      old_fullpath = full_filepath()
      new_fullpath = full_filepath(new_filename)
      save(new_filename)
      log "Deleting old file: #{old_fullpath}"
      File.delete(old_fullpath) if File.file?(old_fullpath)
      return name
    end

    def name()
      @name ||= default_filename.pretty
    end

    def filename()
      "#{name.underscore}.yaml"
    end

    def default_filename()
      "#{@settlement_type}_#{table_value('age').filename_style}_#{table_value('size').filename_style}"
    end

    def filepath()
      @filepath ||= configuration['save_directory']
    end

    def full_filepath(filename = filename(), filepath = filepath())
      Settlement.full_filepath(filename, filepath)
    end

    def to_h()
      output = {
        'name' => name(),
        'filepath' => filepath(),
        'fullpath' => full_filepath(),
        'created_at' => @created_at.to_s,
        'settlement_type' => @settlement_type,
        'tables' => @tables,
        'points_of_interest' => @points_of_interest.collect { |poi_type, pois|
          pois.kind_of?(Array) ? [poi_type, pois.collect { |poi| poi.to_h }] : [poi_type, pois.to_h]
        }.to_h,
        'configuration' => configuration()
      }
      unless hardships.nil?
        output['hardships'] = hardships.collect { |hardship| hardship.to_h }
      end
      return output
    end

    def self.full_filepath(filename, filepath = Configuration.new['save_directory'])
      filename += ".yaml" unless filename =~ /\.yaml$/
      if filename =~ /^\/.*\.yaml$/
        fullpath = filename
      else
        filepath = File.expand_path("#{File.dirname(__FILE__)}/../#{filepath}") unless filepath[0] == '/'
        fullpath = "#{filepath}/#{filename}"
      end
      return fullpath
    end

    def save(filename = filename(), filepath = filepath())
      fullpath = full_filepath(filename, filepath)
      log "Saving #{@settlement_type} to file: #{fullpath}"
      begin
        while File.file?(fullpath) # Add a number in the case of a filename conflict
          if filename =~ /_([0-9]+)\.yaml$/
            next_number = ($1.to_i + 1).to_s
            filename.sub!(/_([0-9]+)\.yaml/, "_#{next_number}.yaml")
          elsif filename =~ /\.yaml$/
            filename.sub!(/\.yaml$/, "_1.yaml")
          else
            raise "Filename expected to have .yaml suffix: #{filename}"
          end
          fullpath = full_filepath(filename, filepath)
          log "Filename conflict detected, saving instead to: #{fullpath}"
        end
        File.open(fullpath, "w") do |f|
          YAML::dump(self, f)
        end
      rescue SystemCallError => e
        log_error "Failed to save #{@settlement_type}:"
        log_error e.message
        return false
      end
      @filepath = filepath
      @name = File.basename(filename, '.yaml').pretty
      return true
    end

    def self.load(filename, filepath = Configuration.new['save_directory'])
      fullpath = full_filepath(filename, filepath)
      SettlementGeneratorHelper.logger.info "Loading settlement from file: #{fullpath}"
      settlement = nil
      File.open(fullpath, "r") do |f|
        settlement = YAML::load(f)
      end
      settlement.log "Loaded settlement"
      return settlement
    end
  end
end