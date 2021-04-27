require 'fileutils'
require_relative 'settlement_generator_helper'
require_relative 'trading_post'

class ExporterMarkdown
  extend SettlementGeneratorHelper

  class << self
    def export_to_markdown(settlement, filename = nil)
      output = ["# #{settlement.settlement_type.pretty}"]
      output.concat(tables_md(settlement))
      output.concat(points_of_interest_md(settlement))
      filename = settlement.default_filename if filename.nil?
      save_to_md(filename, output.join("\n"))
    end

    def tables_md(settlement)
      output = Array.new
      settlement.tables.each_pair do |section, section_tables|
        output << "## #{section.pretty}"
        section_tables.each do |table|
          output << "### #{table['table_name'].pretty}: #{table['name'].pretty}"
          output << table['description']
        end
      end
      return output
    end

    def points_of_interest_md(settlement)
      output = ["## Points of Interest"]
      settlement.points_of_interest.each_pair do |poi_type, pois|
        output << "### #{poi_type.pretty}"
        if pois.kind_of? PlaceOfWorship
          poi = pois
          output << "#### #{poi.size['name'].pretty}"
          output << poi.size['description']
          output << "**Fervency of local following:** #{poi.fervency['name'].pretty}"
          output << poi.fervency['description']
          output << "**Alignment of the faith:** #{poi.alignment.pretty}"
        else
          pois.each do |poi|
            output << "#### #{poi.name.pretty}"
            output << poi.description
            output << poi.hired_help_size['description'] if poi.kind_of? Service and not poi.hired_help_size.nil?
            output << "**Quality:** #{poi.quality['name'].pretty}" unless poi.quality.nil?
            output << poi.quality['description'] unless poi.quality.nil?
          end
        end
      end
      return output
    end

    def save_to_md(filename, text)
      filename_full = "#{filename}.md"
      save_directory = parse_path($configuration['save_directory'])
      # mkdir it?
      saved_settlements = Dir[save_directory]
      if saved_settlements.include? filename_full # Determine unique name if a filename matches
        latest_filename_num = saved_settlements.select { |f| f.include?(filename) and f =~ /\d\.md$/ }
        .collect { |f| f.delete_prefix("#{filename}_").delete_suffix(".md").to_i } # If 
        .sort.last
        filename_num = latest_filename_num.nil? ? 1 : latest_filename_num + 1
        filename_full = "#{filename}_#{filename_num.to_s}.md"
      end
      File.write("#{save_directory}/#{filename_full}", text)
    end
  end
end