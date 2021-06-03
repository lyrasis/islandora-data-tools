require 'bundler/inline'
require 'pathname'
require 'optparse'
require 'pp'

gemfile do
  source 'https://rubygems.org'
  gem 'pry'
end

options = {}
optparse = OptionParser.new{ |opts|
  opts.banner = 'Usage: ruby client_value_compilation.rb -c {clientfile} -m {modsdir}'

  opts.on('-c', '--clients STRING', 'REQUIRED: Path to text file containing client list'){ |c|
    options[:clients] = File.expand_path(c)
    unless File::exist?(c)
      puts "Not a valid client file: #{c}"
      exit
    end
  }
  opts.on('-m', '--mods STRING', 'REQUIRED: Path to directory containing client MODS directories'){ |m|
    options[:mods] = File.expand_path(m)
    unless Dir::exist?(m)
      puts "Not a valid directory: #{m}"
      exit
    end
  }
  opts.on('-o', '--output STRING', 'REQUIRED: Path to directory in which to write output file. Will be written to input directory if not specified.'){ |o|
    Dir::mkdir(o) unless Dir::exist?(o)	
    options[:output] = File.expand_path(o)
  }
  opts.on('-p', '--pattern STRING', 'OPTIONAL: Match pattern in filename. Use to compile values from subset of elements.'){ |p|
    options[:pattern] = p
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
  required = %i[clients mods]
  missing = required.select{ |param| options[param].nil? }
  unless missing.empty?
    raise OptionParser::MissingArgument.new(missing.join(', '))
  end
rescue OptionParser::InvalidOption, OptionParser::MissingArgument
  puts $!.to_s
  puts optparse
  exit
end

report = {
  'Compiled' => [],
  'No MODS' => [],
  'Compilation failed' => []
}

File.readlines(options[:clients]).each do |line|
  client = line.chomp
  valdir = "#{options[:mods]}/#{client}_clean/profile/values"
  if Dir::exist?(valdir)
    puts "Compiling #{client}..."
    cmd = "ruby compile_values.rb -i #{valdir} -o #{options[:output]} -p #{options[:pattern]} -a #{client} -s mods"
    status = system(cmd)
    $?.exitstatus == 0 ? report['Compiled'] << client : report['Compilation failed'] << client
  else
    report['No MODS'] << client
  end
end

report.each do |category, clients|
  next if clients.empty?

  puts "#{category}:"
  clients.each{ |client| puts "  #{client}" }
end

unless Pathname.new(options[:output]).children.empty?
  target = "#{options[:pattern]}_values.csv"
  cmd = "cat #{options[:output]}/*.csv > #{options[:output]}/#{target}"
  system(cmd)
end
