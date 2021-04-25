require 'yaml'
require 'logger'
require_relative 'settlement_generator_helper'

class Configuration < Hash

  def initialize()
    config_file_contents = YAML.load_file(Configuration.configuration_path)
    unless config_file_contents.kind_of? Hash
      puts "Could not load configuration"
      return
    end
    self.merge!(config_file_contents)
    self.transform_values! { |v|
      if v.kind_of? String
        case v.downcase
        when "true", "on", "yes"
          true
        when "false", "off", "no"
          false
        else
          v
        end
      else
        v
      end
    }
    puts "Configurations loaded: #{to_s}"
  end

  def self.configuration_path()
    "#{self.project_path}/config/settlement_generator.yaml"
  end

  def self.project_path()
    File.expand_path('../', __dir__)
  end
end
$configuration = Configuration.new()
