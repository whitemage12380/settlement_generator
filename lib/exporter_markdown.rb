require 'fileutils'
require_relative 'settlement_generator_helper'

module Settlements
  class ExporterMarkdown
    extend SettlementGeneratorHelper

    class << self
      def export_to_markdown(settlement, filename = nil, filepath = nil)
        markdown = to_markdown(settlement)
        filename = settlement.name.underscore if filename.nil?
        if filepath.nil?
          filepath = settlement.configuration.fetch('export_directory', settlement.configuration['save_directory'])
        end
        save_to_md(markdown, filename, filepath)
      end

      def to_markdown(settlement)
        output = ["# #{settlement.settlement_type.pretty}"]
        output.concat(tables_md(settlement))
        output.concat(hardships_md(settlement)) unless settlement.hardships.nil?
        output.concat(points_of_interest_md(settlement))
        return output.join("\n")
      end

      def table_description(table, settlement)
        output = Array.new
        output << table['description'] unless table['description'].nil?
        output.concat(table_impacts(table, settlement))
        return output.join(" ")
      end

      def table_impacts(table, settlement)
        impacted_by_list = settlement.table_modifiers(table)
        negatively_impacted_by_str, positively_impacted_by_str, negatively_impacts_str, positively_impacts_str = [nil, nil, nil, nil]
        unless impacted_by_list.empty?
          negatively_impacted_by = impacted_by_list.select {|m| m[1] < 0}.collect {|m| "#{m[2]} (#{m[1].signed})"}
          negatively_impacted_by_str = impact_string(negatively_impacted_by, "Negatively impacted by")
          positively_impacted_by = impacted_by_list.select {|m| m[1] > 0}.collect {|m| "#{m[2]} (#{m[1].signed})"}
          positively_impacted_by_str = impact_string(positively_impacted_by, "Positively impacted by")
        end
        impacts_list = table.fetch('modifiers', [])
        unless impacts_list.empty?
          negatively_impacts = impacts_list.select {|m| m['modifier'].to_i < 0}.collect {|m| "#{m['table']} (#{m['modifier'].to_i.signed})"}
          negatively_impacts_str = impact_string(negatively_impacts, "Negatively impacts")
          positively_impacts = impacts_list.select {|m| m['modifier'].to_i > 0}.collect {|m| "#{m['table']} (#{m['modifier'].to_i.signed})"}
          positively_impacts_str = impact_string(positively_impacts, "Positively impacts")
        end
        return [negatively_impacted_by_str, positively_impacted_by_str, negatively_impacts_str, positively_impacts_str]
          .reject { |s| s.nil? or s == "" }
      end

      def impact_string(impact_list, prefix)
        impact_list.empty? ? nil : "#{prefix} #{impact_list.join(", ")}."
      end

      def tables_md(settlement)
        output = Array.new
        settlement.tables.each_pair do |section, section_tables|
          output << "## #{section.pretty}"
          section_tables.each do |table|
            if not table['name'].nil?
              output << "### #{table['table_name'].pretty}: #{table['name']}"
            elsif not table['description'].nil?
              output << "### #{table['table_name'].pretty}"
            end
            desc = table_description(table, settlement)
            output << desc unless desc.nil?
          end
        end
        return output
      end

      def points_of_interest_md(settlement)
        output = ["## Points of Interest"]
        settlement.points_of_interest.sort_by { |poi_type, v|
          case poi_type
          when /^places/
            "0_#{poi_type}"
          else
            poi_type
          end
        }.to_h.each_pair do |poi_type, pois|
          output << "### #{poi_type.pretty}"
          if pois.kind_of?(PlaceOfWorship) or pois.first.kind_of?(PlaceOfWorship)
            (pois.kind_of?(Array) ? pois : [pois]).each do |poi|
              output << "#### #{poi.size['name'].pretty}"
              output << poi.size['description']
              output << "**Fervency of local following:** #{poi.fervency['name'].pretty}"
              output << poi.fervency['description']
              output << "**Alignment of the faith:** #{poi.alignment.pretty}"
            end
          else
            pois.each do |poi|
              output << (poi.title.nil? ? "#### #{poi.name}" : "#### #{poi.title}")
              output << "*#{poi.name.pretty}*" unless poi.title.nil?
              output << poi.description
              output << poi.hired_help_size['description'] if (poi.kind_of? Service and not poi.hired_help_size.nil?)
              output << "**Quality:** #{poi.quality['name'].pretty}" unless poi.quality.nil?
              output << poi.quality['description'] unless poi.quality.nil?
              unless poi.owners.nil? or poi.owners.empty?
                output << "**Owners:**"
                output.concat(poi.owners.collect { |o| "* #{o.description}" })
              end
            end
          end
        end
        return output
      end

      def hardships_md(settlement)
        output = ["## Hardships"]
        output << settlement.hardships_description unless settlement.hardships_description.nil?
        settlement.hardships.each do |hardship|
          output << "### #{hardship.name}"
          output << hardship.description
          output << "**Outcome:** #{hardship.outcome['name']} - #{hardship.outcome['description']} (#{hardship.modifiers_string})"
        end
        return output
      end

      def save_to_md(text, filename, filepath)
        filename_full = "#{filename}.md"
        save_directory = parse_path(filepath)
        # mkdir it?
        saved_settlements = Dir[save_directory]
        if saved_settlements.include? filename_full # Determine unique name if a filename matches
          latest_filename_num = saved_settlements.select { |f| f.include?(filename) and f =~ /\d\.md$/ }
          .collect { |f| f.delete_prefix("#{filename}_").delete_suffix(".md").to_i }
          .sort.last
          filename_num = latest_filename_num.nil? ? 1 : latest_filename_num + 1
          filename_full = "#{filename}_#{filename_num.to_s}.md"
        end
        log "Exporting to Markdown: #{save_directory}/#{filename_full}"
        File.write("#{save_directory}/#{filename_full}", text)
      end
    end
  end
end