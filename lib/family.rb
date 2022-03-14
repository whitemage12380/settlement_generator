require_relative 'settlement_generator_helper'
require_relative 'inhabitant_helper'
require_relative 'owner'

module Settlements
  class Family
    include SettlementGeneratorHelper
    include InhabitantHelper

    attr_reader :family_name, :family_name_label, :family_name_translation,
                :race, :ethnicity, :family_members

    def initialize(demographics: nil, adults: 1, children: 0, race: nil, ethnicity: nil, settings: configuration)
      set_configuration(settings, 'owners')
      if demographics.kind_of? Hash and not race.kind_of? Race
        @race, @ethnicity = random_race_and_ethnicity(demographics)
      elsif demographics.nil? and race.nil?
        raise "Cannot create a family with neither demographics nor provided race"
      else
        @race, @ethnicity = race, ethnicity
      end
      @family_name, @family_name_label, @family_name_translation = random_family_name(@race, @ethnicity) if name_table_exist?(@race)
    end

    def name_race()
      @race
    end

    def random_family_name(race, ethnicity)
      name_options = name_table(race).fetch('options', {})
      return nil if name_options['use_family_name'] == false
      unless name_options['family_name_race_chances'].nil?
        race = weighted_random(name_options['family_name_race_chances']).first[0]
        return nil if race == "none"
        ethnicity = random_ethnicity(race)
      end
      if name_table(race).first[1].kind_of? Hash
        if ethnicity.nil?
          # If the name table has ethnicity but we aren't using one, merge the ethnicities together for maximum options
          name_categories = name_table(race).values.reduce(Hash.new) { |memo,obj| memo.deep_merge(obj) }
        else
          name_categories = name_table(race)[ethnicity]
        end
      else
        name_categories = name_table(race)
      end
      family_name_category, family_names = name_categories.select { |category, v| FAMILY_NAME_LABELS.include? category }.first
      chosen_name = family_names.sample
      if chosen_name =~ /([a-zA-Z]+) \(([a-zA-Z]+)\)/
        translated_name = $2
        chosen_name = $1
      else
        translated_name = nil
      end
      return [chosen_name, family_name_category, translated_name]
    end

    def self.random_family_name(demographics = nil, race = nil, ethnicity = nil)
      Family.new(demographics).family_name
    end
  end
end