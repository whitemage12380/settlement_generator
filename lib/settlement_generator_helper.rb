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
end

module SettlementGeneratorHelper

  def parse_path(path_str)
    # Currently only callable from ruby files directly in lib, no nesting (can be changed later)
    return nil if path_str.nil?
    (path_str[0] == "/") ? path_str : "#{Configuration.project_path}/#{path_str}"
  end

  def read_yaml_file(file)
    YAML.load(File.read(file))
  end

  # Might need to do a more traditional roll logic instead of using weight, to easily
  # incorporate both positive and negative modifiers
  # Nah, I can just remove array elements from one side or the other based on modifier and
  # that should work. No, it won't because that doesn't simulate the highest value becoming
  # more likely. I guess I could tack on elements to the other end when I remove one.
  def weighted_random(obj, modifier = 0)
    arr = obj.kind_of?(Array) ? obj : obj.to_a
    weighted_arr = []
    arr.each { |elem|
      if (elem.kind_of? Array) and (elem.length == 2) and ((elem[0].kind_of? String) or (elem[0].kind_of? Symbol)) and (elem[1].kind_of? Hash)
        elem_weight = elem[1].fetch("weight", elem[1][:weight]) if elem[1].kind_of? Hash
      else
        elem_weight = elem.fetch("weight", elem[:weight]) if elem.kind_of? Hash
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

  def roll_on_table(table_name, modifier = 0, settlement_type = @settlement_type)
    file_path = "#{Configuration.project_path}/data/tables/#{settlement_type}/#{table_name.tr(" ", "_")}.yaml"
    table_entries = read_yaml_file(file_path)
    selected_entry = weighted_random(table_entries, modifier)
    if selected_entry.has_key? 'roll'
      selected_entry['roll_result'] = weighted_random(selected_entry['roll'])
      if selected_entry['description'] =~ /\[roll\]/
        selected_entry['description'].sub!(/\[roll\]/, selected_entry['roll_result']['name'])
      end
    end
    return selected_entry
  end

  def roll_race(races_chosen = [], table_name = @config.fetch('race_table', 'standard'))
    file_path = "#{Configuration.project_path}/data/tables/race/#{table_name}.yaml"
    table_entries = read_yaml_file(file_path)
    selected_entry = nil
    while selected_entry.nil? or races_chosen.any? { |r| r == selected_entry.fetch('name', nil) }
      selected_entry = weighted_random(table_entries)
    end
    return selected_entry['name']
  end

  def generate_races(demographics = all_tables_hash['demographics'], table_name = @config.fetch('race_table', 'standard'))
    demographics.fetch('races', []).each do |race_label|
      demographics['chosen_races'] = Hash.new if demographics['chosen_races'].nil?
      chosen_race = roll_race(demographics['chosen_races'])
      demographics['chosen_races'][race_label] = chosen_race
      # Find and replace "race_label race" with race name
      puts demographics['description']
      puts race_label
      puts chosen_race
      demographics['description'].sub!("#{race_label} race", chosen_race)
    end
  end
end