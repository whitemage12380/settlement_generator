require_relative 'settlement_generator_helper'
require_relative 'inhabitant_helper'
require_relative 'family'

module Settlements
  class Owner
    include SettlementGeneratorHelper
    include InhabitantHelper

    attr_reader :first_name, :family,
                :race, :ethnicity, :category, :name_race, :name_ethnicity, :name_category

    
    def initialize(demographics, family: nil, is_child: false, settings: configuration)
      set_configuration(settings, 'owners')
      family_name_race_relationship = roll_on_table('family_relationships', 0, 'names', false)
      race_relationship = family_name_race_relationship['race']
      name_relationship = family_name_race_relationship['name_style']
      @family = Family.new(demographics: demographics, settings: configuration) if family.nil?

      # Set race and ethnicity
      case race_relationship
      when 'family'
        @race = @family.race
        if not (@family.ethnicity.nil?) and rand() < @config.fetch('family_ethnicity_mismatch_chance', 0)
          @ethnicity = random_ethnicity(@race)
        else
          @ethnicity = @family.ethnicity
        end
      when 'demographics'
        @race, @ethnicity = random_race_and_ethnicity(demographics)
      when 'random'
        @race, @ethnicity = random_race_and_ethnicity()
      else
        raise "Unsupported race relationship: #{race_relationship}"
      end
      # Set which race the name comes from
      case name_relationship
      when 'family'
        @name_race = @family.race
        if rand() < @config.fetch('name_ethnicity_mismatch_chance', 0)
          @name_ethnicity = @ethnicity
        else
          @name_ethnicity = @family.ethnicity
        end
      when 'individual'
        @name_race = @race
        if rand() < @config.fetch('name_ethnicity_mismatch_chance', 0)
          @name_ethnicity = @family.ethnicity
        else
          @name_ethnicity = @ethnicity
        end
      when 'demographics'
        @name_race, @name_ethnicity = random_race_and_ethnicity(demographics)
      when 'random'
        @name_race, @name_ethnicity = random_race_and_ethnicity()
      else
        raise "Unsupported name relationship: #{name_relationship}"
      end
      # Set the first name
      @category = is_child ? 'child' : nil
      @first_name, @category = random_first_name(@name_race, @name_ethnicity, @category, false) if name_table_exist?(@name_race)
    end

    def random_first_name(race = @name_race, ethnicity = @name_ethnicity, category = nil, child_ok = false)
      name_options = name_table(race).fetch('options', {})
      unless name_options['first_name_race_chances'].nil?
        race = weighted_random(name_options['first_name_race_chances']).first[0]
        ethnicity = random_ethnicity(race) unless race == @name_race
        @name_race, @name_ethnicity = race, ethnicity
      end
      if name_table(race).first[1].kind_of? Hash
        if ethnicity.nil?
          # If the name table has ethnicity but we aren't using one, merge the ethnicities together for maximum options
          name_categories = name_table(race).values.reduce(Hash.new) { |memo,obj| memo.deep_merge(obj) }
        else
          name_categories = name_table(race)[ethnicity]
        end
      else
        name_categories = name_table
      end
      if category.nil?
        first_name_categories = name_categories.reject { |cat, v| first_name_prohibited_categories(child_ok).include? cat }
        return first_name_categories.to_a.collect { |cat| cat[1].collect { |name| [name, cat[0]] } }.flatten(1).sample
      else
        return [name_categories[category].sample, category]
      end
    end

    def first_name_prohibited_categories(allow_children = false)
      DISALLOWED_NAME_LABELS + FAMILY_NAME_LABELS + (allow_children ? [] : CHILD_LABELS)
    end

    def first_name_plural()
      return first_name[-1] == 's' ? "#{first_name}'s" : "#{first_name}'"
    end

    def family_name()
      @family.family_name
    end

    def full_name()
      if first_name.nil?
        "Unnamed #{race}"
      else
        [first_name, family_name].reject { |n| n.nil? }.join(" ")
      end
    end

    def description()
      race_and_ethnicity = ethnicity.nil? ? race.pretty : "#{race.pretty} - #{ethnicity}"
      name_race_and_ethnicity = name_ethnicity.nil? ? name_race.pretty : "#{name_race.pretty} - #{name_ethnicity}"
      # Family
      if @race != @family.race
        family_race_str = "Raised by a #{@family.race} family"
        family_ethnicity_str = " (#{@family.ethnicity})" unless @family.ethnicity.nil?
      end
      unless family_race_str.nil?
        family_str = " #{family_race_str.to_s + family_ethnicity_str.to_s}."
      end
      # Name origin
      if name_race != race or name_ethnicity != ethnicity or @race != @family.race
        name_origin_race_str = " #{@name_race.pretty}"
        name_origin_ethnicity_str = " #{@name_ethnicity}" unless @name_ethnicity.nil?
      end
      name_origin_category_str = " #{@category}" unless [nil, 'any'].include? @category
      unless name_origin_race_str.nil? and name_origin_category_str.nil?
        name_origin_str = " Name origin:#{name_origin_race_str.to_s + name_origin_ethnicity_str.to_s + name_origin_category_str.to_s}."
      end

      return "#{full_name} (#{race_and_ethnicity}).#{family_str.to_s}#{name_origin_str.to_s}"
    end

    def print()
      puts description
    end

    attr_reader :first_name, :family_name, :family_name_label, :family,
                :race, :ethnicity, :category, :name_race, :name_ethnicity, :name_category

    def to_h()
      output = {
        'first_name' => @first_name,
        'last_name' => family_name(),
        'full_name' => full_name(),
        'race' => @race,
        'name_race' => @name_race,
        'description' => description()
      }
      output['ethnicity'] = @ethnicity unless @ethnicity.nil?
      output['category'] = @category unless [nil, 'any'].include? @category
      output['name_ethnicity'] = @name_ethnicity unless @name_ethnicity.nil?
      output['name_category'] = @name_category unless [nil, 'any'].include? @name_category
      output['family_race'] = @family.race unless @family.race.nil?
      output['family_ethnicity'] = @family.ethnicity unless @family.ethnicity.nil?
      output['family_name_label'] = @family.family_name_label unless @family.family_name_label.nil?
      output['family_name_translation'] = @family.family_name_translation unless @family.family_name_translation.nil?
      return output
    end
  end
end