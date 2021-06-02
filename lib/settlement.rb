require_relative 'settlement_generator_helper'

class Settlement
  include SettlementGeneratorHelper

  attr_reader :settlement_type, :tables, :points_of_interest

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

  def hardship_modifiers()
    return []
  end

  def modifiers(tables = all_tables)
    # puts all_tables.to_s
    # puts "..."
    # puts (all_tables.collect { |table|
    #     table.fetch('modifiers', []).collect { |m|
    #       [m['table'], m['modifier']]
    #     }
    #   } + hardship_modifiers()).to_s
    # puts (all_tables.collect { |table|
    #     table.fetch('modifiers', []).collect { |m|
    #       [m['table'], m['modifier']]
    #     }
    #   } + hardship_modifiers()).flatten(1).to_s
    # puts "---"
    return modifier_list(tables)
    .group_by { |m| m[0] } # Hash - keys are deduped table names, vals are arrays of [table, modifier] arrays
    .reject { |k,v| k.nil? } # Remove nil key (case of no modifiers)
    .transform_values  { |m|
      m.sum { |n| n[1] } # Get modifiers for a single table and sum them
    } # Hash - keys are deduped table names, vals are the final modifiers for those tables
  end

  def table_modifiers(table, tables = all_tables)
    return modifier_list_with_reason(tables).select { |m| m[0] == table }
  end

  def table_modifiers_string(table, tables = all_tables)
    modifier_arrays = table_modifiers(table, tables).select { |tm| tm[1] != 0 }.collect { |tm|
      "#{tm[1].signed} from #{tm[2]}"
    }.join(", ")
  end

  # Returns a list of modifiers, where each modifier is an array of [table, modifier number]
  def modifier_list(tables = all_tables)
    return modifier_list_with_reason(tables).collect { |m| [m[0], m[1]] }
    # return (tables.collect { |table|
    #     table.fetch('modifiers', []).collect { |m|
    #       [m['table'], m['modifier']]
    #     }
    #   } # Array of [table, modifier] arrays, overly nested, possibly lopsided
    #   .flatten(1) + ## Array of [name, modifier] arrays
    #     hardship_modifiers() # Add modifiers from hardships in same format
    # )
  end

  def modifier_list_with_reason(tables = all_tables)
    return (tables.collect { |table|
        table.fetch('modifiers', []).collect { |m|
          [m['table'], m['modifier'], table['table_name']]
        }
      } # Array of [table, modifier] arrays, overly nested, possibly lopsided
      .flatten(1) + ## Array of [name, modifier] arrays
        hardship_modifiers_with_reason() # Add modifiers from hardships in same format
    )
  end

  def default_filename()
    "#{@settlement_type}_#{table_value('age').filename_style}_#{table_value('size').filename_style}"
  end
end