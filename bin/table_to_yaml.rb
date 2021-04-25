#!usr/bin/env ruby
require 'csv'
require 'yaml'

class String
  def is_integer?
    self.to_i.to_s == self
  end
end

def get_weight(range_text)
  if range_text.is_integer?
    return range_text.to_i
  else
    return range_text.split("-")[1].to_i - range_text.split("-")[0].to_i + 1
  end
end

table = "#{__dir__}/../tmp/#{ARGV[0]}.txt"
entries = Array.new
File.readlines(table).each do |line|
  if line[0].is_integer?
    entry_range = line.split.first
    if entry_range =~ /-/
      entry_weight = get_weight(entry_range)
    else
      entry_weight = 1
    end
    line.delete_prefix!(entry_range)
    entry_name = line.split(".").first.strip
    line.strip!
    line.delete_prefix!("#{entry_name}.")
    entry_desc = line.strip
    entries << {'weight' => entry_weight, 'name' => entry_name, 'description' => entry_desc}
  elsif line.split.first[0].is_integer?
    entry = entries.last
    entry['roll'] = Array.new if entry['roll'].nil?
    subentry_range = line.split.first
    line.delete_suffix!(":")
    subentry_weight = get_weight(subentry_range)
    line.strip!
    line.delete_prefix!(subentry_range)
    line.delete_prefix!(":")
    subentry_name = line.strip.chomp(",")
    entry['roll'] << {'weight' => subentry_weight, 'name' => subentry_name}
  elsif line =~ /\(([+-])([0-9]+) to ([^\)]+)\)/
    mod_sign = $1
    mod_number = $2
    mod_table = $3.delete_suffix(" roll")
    mod_table = $3.delete_suffix(" rolls")
    modifier = {
      'modifier' => "#{mod_sign}#{mod_number}".to_i,
      'table'    => mod_table
    }
    entry = entries.last
    entry['modifiers'] = Array.new if entry['modifiers'].nil?
    entry['modifiers'] << modifier
  else
    entries.last['description'].concat(" " + line.strip)
  end
end
puts entries.to_s
settlement_type = ARGV[0].sub(/_[a-z]+$/, "")
table_name = ARGV[0].delete_prefix("#{settlement_type}_")
File.open("#{__dir__}/../data/tables/#{settlement_type}/#{table_name}.yaml", "w") { |f|
  f.write(entries.to_yaml)
}