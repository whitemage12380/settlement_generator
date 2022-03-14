

class String

  def pretty()
    output = split(/ |\_/).map(&:capitalize).join(" ")
            .split("-").map(&:capitalize).join("-")
            .split("(").map(&:capitalize).join("(")
    output = capitalize.gsub(/_/, " ")
            .gsub(/\b(?<!\w['])[a-z]/) { |match| match.capitalize }
    return output
  end

  def underscore()
    self.gsub(/::/, '/').
    gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
    gsub(/([a-z\d])([A-Z])/,'\1_\2').
    tr("- ", "_").
    downcase
  end

  def filename_style()
    return downcase.tr(" ", "_")
  end

  def is_integer?
    self.to_i.to_s == self
  end
end

class Integer
  def signed()
    sign = self >= 0 ? '+' : ''
    "#{sign}#{self}"
  end

  def is_integer?
    true
  end
end

class Hash
  def deep_merge(second)
    merger = proc { |_, v1, v2| Hash === v1 && Hash === v2 ? v1.merge(v2, &merger) : Array === v1 && Array === v2 ? v1 | v2 : [:undefined, nil, :nil].include?(v2) ? v1 : v2 }
    merge(second.to_h, &merger)
  end
  def deep_merge!(second)
    merger = proc { |_, v1, v2| Hash === v1 && Hash === v2 ? v1.merge(v2, &merger) : Array === v1 && Array === v2 ? v1 | v2 : [:undefined, nil, :nil].include?(v2) ? v1 : v2 }
    merge!(second.to_h, &merger)
  end
end

module Settlements
  module SettlementGeneratorHelper
    require 'yaml'
    require_relative 'settlement_generator_logger'
    require_relative 'configuration'
    require_relative 'race'

    def init_configuration(settings, configuration_path = nil, settlement_type = nil)
      @configuration = Configuration.new(settings, configuration_path)
      @config = configuration.fetch(settlement_type, {})
    end

    def set_configuration(settings, settlement_type = nil)
      @configuration = settings
      @config = settings.fetch(settlement_type, {})
    end

    def self.configuration()
      Configuration.new({"show_configuration" => false})
    end

    def configuration()
      # puts "Configuration: #{(@configuration.nil? ? "nil" : @configuration)}"
      raise "configuration not found" if @configuration.nil? # temp
      @configuration ||= Configuration.new
    end

    def init_logger(log_level = configuration.fetch('log_level', 'INFO'))
      Settlements::SettlementGeneratorLogger.logger(log_level)
    end

    def logger()
      Settlements::SettlementGeneratorLogger.logger
    end

    # def self.logger(log_level = 'INFO')
    #   @logger ||= Logger.new(STDOUT, log_level)
    # end

    # def logger(log_level = configuration.fetch('log_level', 'INFO'))
    #   SettlementGeneratorHelper.logger
    # end

    # def init_logger()
    #   if $log.nil?
    #     if @log_level.nil?
    #       log_level = $configuration['log_level'] ? $configuration['log_level'].upcase : Logger::INFO
    #     else
    #       log_level = @log_level
    #     end
    #     $log = Logger.new(STDOUT, level: log_level)
    #   end
    #   $messages = StringIO.new() if $messages.nil?
    #   $message_log = Logger.new($messages, level: log_level) if $message_log.nil?
    # end

    def log_debug(message)
      logger.debug(message)
    end

    def log(message)
      logger.info(message)
    end

    def log_warning(message)
      logger.warn(message)
    end

    def log_error(message)
      logger.error(message)
    end

    def verbose(str)
      puts str if configuration['verbose'] == true
    end

    # def log_important(message)
    #   init_logger()
    #   $log.info(message)
    #   $message_log.info(message)
    # end

    def parse_path(path_str)
      # Currently only callable from ruby files directly in lib, no nesting (can be changed later)
      return nil if path_str.nil?
      (path_str[0] == "/") ? path_str : "#{Configuration.project_path}/#{path_str}"
    end

    def read_yaml_file(file)
      YAML.load(File.read(file))
    end

    def read_table(table_name, table_directory = @settlement_type)
      read_yaml_file(table_path(table_name, table_directory))
    end

    def table_path(table_name, table_directory = @settlement_type)
      "#{Configuration.project_path}/data/tables/#{table_directory}/#{table_name.filename_style}.yaml"
    end

    def table_exist?(table_name, table_directory = @settlement_type)
      File.exist? table_path(table_name, table_directory)
    end

    def weighted_random(obj, modifier = 0)
      arr = obj.kind_of?(Array) ? obj : obj.to_a
      modifier = 0 if modifier.nil?
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
      if self.class.method_defined? :restrictions
        table_restrictions = restrictions[table_name]
        unless table_restrictions.nil?
          log "Restricting entries on #{table_name}: #{table_restrictions.join(', ')}"
          table_entries.reject! { |entry| table_restrictions.include? entry['name'] }
        end
      end
      selected_entry = weighted_random(table_entries, modifier)
      if log_roll == true
        roll_modifier_str = modifier != 0 ? " (#{modifier.signed})" : ''
        modifiers_str = " (#{table_entry_modifiers_str(selected_entry)})" if entry_has_modifiers? selected_entry
        if selected_entry['name'].nil? and selected_entry['description'].nil?
          logged_str = selected_entry.to_s
        elsif selected_entry['name'].nil?
          logged_str = selected_entry['description']
        else
          logged_str = selected_entry['name']
        end
        log "Rolled on #{table_name} table#{roll_modifier_str}: #{logged_str.pretty}#{modifiers_str}"
      end
      if selected_entry.kind_of?(Hash) and selected_entry.has_key?('roll')
        selected_entry['roll_result'] = weighted_random(selected_entry['roll'])
        log "Sub-table roll result on #{table_name} table: #{selected_entry['roll_result']['name'].pretty}" if log_roll == true
        if selected_entry['description'] =~ /\[roll\]/
          selected_entry['description'].sub!(/\[roll\]/, selected_entry['roll_result']['name'])
        end
        selected_entry.merge!(selected_entry['roll_result'].reject {|k,v| ['weight', 'name', 'description'].include? k })
      end
      return selected_entry
    end

    def roll(range, modifier = 0)
      if range.kind_of?(String) and range =~ /^(\d+)-(\d+)$/
        min = $1.to_i
        max = $2.to_i
      elsif range.kind_of?(String) and range =~ /^(\d+)d(\d+)([-+]?)(\d*)$/
        die_num = $1.to_i
        die_size = $2.to_i
        die_mod = ($3 == '' or $4 == '') ? 0 : "#{$3}#{$4}".to_i
        return Array.new(die_num) { rand(1..die_size) }.sum() + die_mod
      elsif range.kind_of?(Array)
        min, max = range
      elsif range.kind_of?(Range)
        return rand(range) + modifier
      elsif (range.kind_of? String or range.kind_of? Integer) and range.is_integer?
        return range.to_i
      else
        raise "Unsupported format for roll: #{range.to_s}"
      end
      return rand(min..max) + modifier
    end

    def roll_race(chosen_races = {}, table_name = @config.fetch('race_table', 'standard'))
      file_path = "#{Configuration.project_path}/data/tables/race/#{table_name}.yaml"
      table_entries = read_yaml_file(file_path)
      selected_entry = nil
      while selected_entry.nil? or (chosen_races.values.any? { |r| r.name == selected_entry.fetch('name', nil) } and chosen_races.size < table_entries.size)
        selected_entry = weighted_random(table_entries)
      end
      return Race.new(selected_entry)
    end

    def entry_has_modifiers?(entry)
      entry.fetch('modifiers', []).any? { |m| m['modifier'] != 0 }
    end

    def table_entry_modifiers_str(entry)
      entry.fetch('modifiers', []).select { |m| m['modifier'] != 0 }.collect { |m| "#{m['modifier'].signed} to #{m['table']}"}.join(", ")
    end
  end
end