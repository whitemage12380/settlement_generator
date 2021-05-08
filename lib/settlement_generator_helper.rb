require 'yaml'
require_relative 'configuration'

class String

  def pretty()
    output = split(/ |\_/).map(&:capitalize).join(" ")
            .split("-").map(&:capitalize).join("-")
            .split("(").map(&:capitalize).join("(")
    output = capitalize.gsub(/_/, " ")
            .gsub(/\b(?<!\w['])[a-z]/) { |match| match.capitalize }
    return output
  end

  def filename_style()
    return downcase.tr(" ", "_")
  end
end

class Integer
  def signed()
    sign = self >= 0 ? '+' : ''
    "#{sign}#{self}"
  end
end

module SettlementGeneratorHelper
  require 'logger'

  def init_logger()
    $log = Logger.new(STDOUT) if $log.nil?
    $log.level = $configuration['log_level'] ? $configuration['log_level'].upcase : Logger::INFO
    $messages = StringIO.new() if $messages.nil?
    $message_log = Logger.new($messages) if $message_log.nil?
    $message_log.level = Logger::INFO
  end

  def debug(message)
    init_logger()
    $log.debug(message)
  end

  def log(message)
    init_logger()
    $log.info(message)
  end

  def log_error(message)
    init_logger()
    $log.error(message)
  end

  def log_important(message)
    init_logger()
    $log.info(message)
    $message_log.info(message)
  end

  def verbose(str)
    puts str if $configuration['verbose'] == true
  end

  def parse_path(path_str)
    # Currently only callable from ruby files directly in lib, no nesting (can be changed later)
    return nil if path_str.nil?
    (path_str[0] == "/") ? path_str : "#{Configuration.project_path}/#{path_str}"
  end

  def read_yaml_file(file)
    YAML.load(File.read(file))
  end

  def read_table(table_name, table_directory = @settlement_type)
    file_path = "#{Configuration.project_path}/data/tables/#{table_directory}/#{table_name.filename_style}.yaml"
    return read_yaml_file(file_path)
  end

  def weighted_random(obj, modifier = 0)
    arr = obj.kind_of?(Array) ? obj : obj.to_a
    weighted_arr = []
    arr.each { |elem|
      if (elem.kind_of? Array) and (elem.length == 2) and ((elem[0].kind_of? String) or (elem[0].kind_of? Symbol)) and (elem[1].kind_of? Hash)
        elem_weight = elem[1].fetch("weight", elem[1][:weight]) if elem[1].kind_of? Hash
      elsif elem.kind_of? Hash
        elem_weight = elem.fetch("weight", elem[:weight])
      else
        elem_weight = 1
      end
      probability = elem_weight ? elem_weight : 10
      probability.times do
        weighted_arr << elem
      end
    }
    if modifier > 0
      weighted_arr.shift(modifier)
      elem = weighted_arr.last
      weighted_arr.concat(Array.new(modifier) {elem})
    elsif modifier < 0
      neg_modifier = 0 - modifier
      weighted_arr.pop(neg_modifier)
      elem = weighted_arr.first
      weighted_arr.unshift(*Array.new(neg_modifier) {elem})
    end
    return [weighted_arr.sample].to_h if obj.kind_of? Hash
    return weighted_arr.sample
  end

  def roll_on_table(table_name, modifier = 0, table_directory = @settlement_type, log_roll = true)
    table_entries = read_table(table_name, table_directory)
    selected_entry = weighted_random(table_entries, modifier)
    if log_roll == true
      roll_modifier_str = modifier != 0 ? " (#{modifier.signed})" : ''
      modifiers_str = " (#{table_entry_modifiers_str(selected_entry)})" if entry_has_modifiers? selected_entry
      log "Rolled on #{table_name} table#{roll_modifier_str}: #{selected_entry['name'].pretty}#{modifiers_str}"
    end
    if selected_entry.kind_of? Hash and selected_entry.has_key? 'roll'
      selected_entry['roll_result'] = weighted_random(selected_entry['roll'])
      log "Sub-table roll result on #{table_name} table: #{selected_entry['roll_result']['name'].pretty}" if log_roll == true
      if selected_entry['description'] =~ /\[roll\]/
        selected_entry['description'].sub!(/\[roll\]/, selected_entry['roll_result']['name'])
      end
    end
    return selected_entry
  end

  def roll(range, modifier = 0)
    if range.kind_of?(String) and range =~ /(\d+)-(\d+)/
      min = $1.to_i
      max = $2.to_i
    elsif range.kind_of?(Array)
      min, max = range
    elsif range.kind_of?(Range)
      return rand(range) + modifier
    end
    return rand(min..max) + modifier
  end

  def roll_race(races_chosen = [], table_name = @config.fetch('race_table', 'standard'))
    file_path = "#{Configuration.project_path}/data/tables/race/#{table_name}.yaml"
    table_entries = read_yaml_file(file_path)
    selected_entry = nil
    while selected_entry.nil? or races_chosen.values.any? { |r| r == selected_entry.fetch('name', nil) }
      selected_entry = weighted_random(table_entries)
    end
    return selected_entry['name']
  end

  def generate_races(demographics = all_tables_hash['demographics'], table_name = @config.fetch('race_table', 'standard'))
    demographics.fetch('races', []).each do |race_label|
      demographics['chosen_races'] = Hash.new if demographics['chosen_races'].nil?
      chosen_race = roll_race(demographics['chosen_races'])
      log "Chose #{race_label} race: #{chosen_race}"
      demographics['chosen_races'][race_label] = chosen_race
      demographics['description'].sub!("#{race_label} race", chosen_race)
    end
  end

  def entry_has_modifiers?(entry)
    entry.fetch('modifiers', []).any? { |m| m['modifier'] != 0 }
  end

  def table_entry_modifiers_str(entry)
    entry.fetch('modifiers', []).select { |m| m['modifier'] != 0 }.collect { |m| "#{m['modifier'].signed} to #{m['table']}"}.join(", ")
  end
end