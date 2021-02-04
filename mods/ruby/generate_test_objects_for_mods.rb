# standard library
require 'fileutils'
require 'optparse'

# other dependencies
require 'bundler/inline'
gemfile do
  source 'https://rubygems.org'
  gem 'pry'
end

options = {}
OptionParser.new{ |opts|
  opts.banner = 'Usage: ruby generate_test_objects_for_mods.rb -i {input_dir} -f {object_file_path}'

  opts.on('-i', '--input INPUTDIR', 'Path to directory containing MODS files'){ |i|
    options[:input] = i
    unless Dir::exist?(i)
      puts "Not a valid input directory: #{i}"
      exit
    end
  }
  opts.on('-f', '--filepath FILEPATH', 'Path to a file to be copied/renamed to go with each MODS file'){ |f|
    if File::exist?(f)
      options[:file] = File.expand_path(f)
    else
      puts "No file exists at #{f}"
      exit
    end
  }
  opts.on('-h', '--help', 'Prints this help'){
    puts opts
    exit
  }
}.parse!

indir = Dir.new(options[:input])
mods = indir.children.select{ |filename| filename.end_with?('.xml') }
object_ext = File.extname(options[:file])

mods.each{ |mods|
  filename = File.basename("#{options[:input]}/#{mods}", '.xml')
  FileUtils.copy_file(options[:file], "#{options[:input]}/#{filename}#{object_ext}")
}

