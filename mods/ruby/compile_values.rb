require 'bundler/inline'
require 'csv'
require 'fileutils'
require 'pathname'
require 'optparse'
require 'pp'

gemfile do
  source 'https://rubygems.org'
  gem 'pry'
end

options = {}
optparse = OptionParser.new{ |opts|
  opts.banner = 'Usage: ruby compile_values.rb -i {input_dir} -p {filename match pattern} -a {added}'

  opts.on('-i', '--input STRING', 'REQUIRED: Path to directory containing values files'){ |i|
    options[:input] = File.expand_path(i)
    unless Dir::exist?(i)
      puts "Not a valid input directory: #{i}"
      exit
    end
  }
  opts.on('-o', '--output STRING', 'OPTIONAL: Path to directory in which to write output file. Will be written to input directory if not specified.'){ |o|
    Dir::mkdir(o) unless Dir::exist?(o)	
    options[:output] = File.expand_path(o)
  }
  opts.on('-p', '--pattern STRING', 'OPTIONAL: Match pattern in filename. Use to compile values from subset of elements.'){ |p|
    options[:pattern] = p
  }
  opts.on('-a', '--a STRING', 'OPTIONAL: Added value. If included, a column will be included in output file with this value in each row, and this will be added to the beginning of the output file name'){ |a|
    options[:added] = a
  }
  opts.on('-s', '--strip STRING', 'OPTIONAL: string indicating node to strip from beginning of xpaths/filenames'){ |s|
    options[:strip] = s.split(',')
  }
  opts.on('-h', '--help', 'Prints this help'){
    puts opts
    exit
  }
}
begin
  optparse.parse!
  required = %i[input]
  missing = required.select{ |param| options[param].nil? }
  unless missing.empty?
    raise OptionParser::MissingArgument.new(missing.join(', '))
  end
rescue OptionParser::InvalidOption, OptionParser::MissingArgument
  puts $!.to_s
  puts optparse
  exit
end

class OptBundle
  attr_reader :input, :pattern, :added, :strip, :output
  def initialize(opts)
    @input = opts[:input]
    @pattern = opts[:pattern]
    @added = opts[:added] || ''
    @strip = opts[:strip] || []
    @output = opts[:output] || opts[:input]
  end

  def print
    puts 'Will run using options:'
    self.instance_variables.each do |var|
      puts "  #{var}: #{instance_variable_get(var)}"
    end
    puts ''
  end
end

class InputFile
  attr_reader :path

  VAL_THRESHOLD = 5000
  
  def initialize(path:, added:, strip:)
    @path = path
    @added = added
    @strip = strip
    @values = []
  end

  def write_values(outfile)
    File.readlines(@path).each do |row|
      val = Value.new(row.chomp, xpath)
      val.add(@added) unless @added.empty?
      @values << val.to_a
      next unless value_threshold_met?
      
      outfile.write(@values)
      @values = []
    end
    outfile.write(@values)
  end

  private

  def value_threshold_met?
    @values.length == VAL_THRESHOLD
  end

  def xpath
    val = @path.basename.to_s.sub('.txt', '').gsub('_', '/')
    @strip.each{ |removestr| val = val.sub(/^#{removestr}\//, '') }
    val
  end
end

class Value
  attr_reader :occurrences, :examples, :value, :added
  def initialize(row, xpath)
    split = row.split('|||')
    @occurrences, @examples, @value = split[0], split[1].split('^^^'), split[2]
    @xpath = xpath
  end

  def add(added)
    @added = added
  end

  def to_a
    arr = [@xpath, @value, @occurrences, @examples.join('; ')]
    return arr.unshift(@added) if @added

    arr
  end
end

class InputDir
  def initialize(opts)
    @path = Pathname.new(opts.input)
    @added = opts.added
    @pattern = opts.pattern
    @strip = opts.strip
  end

  def files
    return @path.children.map{ |child| InputFile.new(path: child, added: @added) } if @pattern.nil?
    
    matching = @path.children.select{ |child| child.to_s[@pattern] }
    matching.map{ |child| InputFile.new(path: child, added: @added, strip: @strip ) } 
  end
end

class OutputCsv
  def initialize(opts)
    @dir = opts.output
    @pattern = opts.pattern
    @added = opts.added
    @path = "#{@dir}/#{filename}"
    write_headers
  end

  def path
    @path
  end

  def write(values)
    CSV.open(@path, 'a') do |csv|
      values.each{ |val| csv << val }
    end
  end

  private

  def headers
    hdrs = %w[xpath value occurrences examples]
    hdrs = hdrs.unshift('added') unless @added.empty?
    hdrs
  end

  def write_headers
    CSV.open(@path, 'w'){ |csv| csv << headers }
  end
  
  def filename
    return 'values.csv' if @pattern.nil? && @added.empty?
    return "#{@added}_values.csv" if @pattern.nil?
    return "#{@pattern}_values.csv" if @added.empty?
    "#{@added}_#{@pattern}_values.csv"
  end
end

opts = OptBundle.new(options)
opts.print

outfile = OutputCsv.new(opts)
puts "\n\nWill write to #{outfile.path}"

dir = InputDir.new(opts)
dir.files.each do |file|
  puts "Writing values from #{file.path}"
  file.write_values(outfile)
end
  


