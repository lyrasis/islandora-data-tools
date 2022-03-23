#!/usr/bin/env ruby
# frozen_string_literal: true

# Input directory will have one text file per client instance.
# File is the result of running the following Solr query for each instance:
#   http://localhost:{local_port}/solr/collection1/select?q=*:*&wt=csv&rows=0&facet
# This list is only available in CSV format because CSV is the only format that has a
#   separate header row. This is the only way to get out a list of all dynamic fields
#   created without retrieving and parsing all full records to get fields names.

require 'csv'
require 'optparse'
require 'pp'

require 'bundler/inline'
gemfile do
  source 'https://rubygems.org'
  gem 'pry', '>= 0.13.0'
end

options = {}
OptionParser.new{ |opts|
  opts.banner = 'Usage: ruby process_csv_field_results.rb -i {path_to_input_directory} -o {path_to_output_file}'

  opts.on('-i', '--input path_to_inputdir', 'Path to directory containing Solr output files for client instances'){ |i|
    options[:input] = i
  }
  opts.on('-o', '--output path_to_outputdir ', 'Path to output directory'){ |o|
    options[:output] = o
  }

}.parse!

FIELD_SUFFIXES = %w[dt hlt kw mdt mlt ms mt s ss t]

field_data = {}

def get_client(filename)
  filename.sub(/_.*$/, '')
end

# returns array of fieldnames, minus fieldnames beginning with 'RELS_EXT_isSequenceNumberOf'
def get_fieldnames(filename, options)
  path = "#{options[:input]}/#{filename}"
  File.read(path)
    .chomp
    .sub('_version_', '%US%version%US%')
    .gsub(',_', '%COMMA%_')
    .gsub(', ', '%COMMA% ')  
    .split(',')
    .reject{ |field| field.start_with?('RELS_EXT_isSequenceNumberOf') }
end

def fix_fieldnames_with_commas(fields)
  fields = fields.map do |field|
    field.sub('%US%version%US%', '_version_')
      .gsub('%COMMA%', ',')
      .gsub('"', '')
  end
  fields
end

def normalize_fieldname(fieldname)
  field_end = fieldname.split('_').last
  fieldname = fieldname.sub(/_#{field_end}$/, '') if FIELD_SUFFIXES.any?(field_end)
  fieldname
end

Dir.children(options[:input]).each do |file|
  puts "Processing #{file}..."
  client = get_client(file).to_sym
  fields = get_fieldnames(file, options)
  good_fields = fix_fieldnames_with_commas(fields)
  good_fields.each do |field|
    field_data.key?(field) ? field_data[field][:clients] << client : field_data[field] = { clients: [client] }
  end
  field_data.keys.sort.each do |fieldname|
    field_data[fieldname][:normalized] = normalize_fieldname(fieldname)
  end
end

norm_data = {}

field_data.values.each do |hash|
  norm = hash[:normalized]
  norm_data.key?(norm) ? norm_data[norm] << hash[:clients] : norm_data[norm] = [hash[:clients]]
end

norm_data.transform_values!{ |arr| arr.flatten.uniq }

suffix_path = "#{options[:output]}/solr_fields_suffixes.tsv"
CSV.open(suffix_path, 'wb', col_sep: "\t") do |csv|
  csv << %w[solr_field norm_field client]
  field_data.each do |solr_field, data|
    norm = data[:normalized]
    data[:clients].each{ |client| csv << [solr_field, norm, client] }
  end
end

norm_path = "#{options[:output]}/solr_fields_normalized.tsv"
CSV.open(norm_path, 'wb', col_sep: "\t") do |csv|
  csv << %w[norm_solr_field client]
  norm_data.each do |norm_field, clients|
    clients.each{ |client| csv << [norm_field, client] }
  end
end


