require 'bundler/inline'
require 'fileutils'
require 'optparse'

gemfile do
  source 'https://rubygems.org'
  gem 'pry'
end

options = {}
OptionParser.new{ |opts|
  opts.banner = 'Usage: ruby select_specified_files.rb -i {input_file} -d {source_dir} -o {path/to/output/dir}'
  
  # One file name per line
  opts.on('-i', '--input INPUTFILE', 'Path to file containing list of files to select.'){ |i|
    options[:input] = File.expand_path(i)
    unless File::exist?(options[:input])
      puts "Not a valid input directory: #{options[:input]}"
      exit
    end
  }
  opts.on('-d', '--sourcedir SOURCEDIR', 'Path to directory containing files to select from.'){ |d|
    options[:dir] = File.expand_path(d)
    unless Dir::exist?(options[:dir])
      puts "Source directory #{options[:dir]} does not exist."
      exit
    end
  }
  opts.on('-o', '--outputdir OUTPUTDIR', 'Path to directory to select files to.'){ |o|
    options[:output] = File.expand_path(o)
    FileUtils.mkdir_p(options[:output])
  }
  opts.on('-h', '--help', 'Prints this help'){
    puts opts
    exit
  }
}.parse!

class FileList
  def initialize(inputfile:)
    @list = []
    File.foreach(inputfile, chomp: true){ |ln| @list << ln }
  end

  def paths(sourcedir:)
    @list.map{ |filename| "#{sourcedir}/#{filename}" }
  end
end

files = FileList.new(inputfile: options[:input])
paths = files.paths(sourcedir: options[:dir])
paths.each do |filepath|
  next unless File::exist?(filepath)

  FileUtils.cp(filepath, options[:output])
end
