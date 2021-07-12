require_relative 'settlement_generator_helper'

module Settlements
  module InhabitantHelper
    include SettlementGeneratorHelper

    CHILD_LABELS = ['child']
    FAMILY_NAME_LABELS = ['clan', 'family', 'surname']
    DISALLOWED_NAME_LABELS = ['options']

    def name_table(race = name_race)
      if race == name_race and @name_table.nil?
        @name_table = read_table(race, 'names')
      else
        return read_table(race, 'names')
      end
    end

    def name_table_exist?(race = name_race)
      table_exist?(race, 'names')
    end

    # def owners_config()
    #   $configuration.fetch('owners', {})
    # end

    def random_race_and_ethnicity(demographics = nil)
      race = Race.new(random_race(demographics))
      ethnicity = random_ethnicity(race)
      return [race, ethnicity]
    end

    def random_race(demographics = nil)
      if demographics.nil? or demographics['chosen_races'].nil?
        race_chances = [{'name' => 'other', 'weight' => 1}]
      else
        race_chances = demographics['races'].collect { |r|
          r['name'] == 'other' ? r : {
            'name' => demographics['chosen_races'][r['name']],
            'weight' => r['weight']
          }
        }
      end
      race = Race.new(weighted_random(race_chances))
      race = roll_race() if race == 'other'
      return race
    end

    def random_ethnicity(race)
      return nil unless name_table_exist?(race) and name_table(race).first[1].kind_of?(Hash) and @config['use_ethnicity'] == true
      return name_table(race).keys.reject{|e| e == 'options'}.sample
    end
  end
end