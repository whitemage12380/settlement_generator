require 'yaml'
require 'logger'
require_relative 'settlement_generator_helper'

module Settlements
  class Configuration < Hash

    def initialize(custom_settings = {}, configuration_path = nil)
      custom_settings = {} unless custom_settings.kind_of? Hash
      configuration_path ||= Configuration.configuration_path
      config_file_contents = YAML.load_file(configuration_path)
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
      self.deep_merge!(custom_settings)
      puts "Configurations loaded: #{to_s}" unless self.fetch('show_configuration', true) == false
    end

    def self.configuration_path()
      "#{self.project_path}/config/settlement_generator.yaml"
    end

    def self.project_path()
      File.expand_path('../', __dir__)
    end
  end
end
