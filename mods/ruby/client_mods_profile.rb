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
  opts.banner = 'Usage: ruby client_mods_profile.rb -c {clientfile} -m {modsdir}'

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
  'Profiled' => [],
  'No MODS' => [],
  'Profiling failed' => []
}

File.readlines(options[:clients]).each do |line|
  client = line.chomp
  modsdir = "#{options[:mods]}/#{client}_clean"
  if Dir::exist?(modsdir)
    puts "Profiling #{client}..."
    `ruby profile_xml.rb -i #{modsdir}`
    $?.exitstatus == 0 ? report['Profiled'] << client : report['Profiling failed'] << client
  else
    report['No MODS'] << client
  end
end

report.each do |category, clients|
  next if clients.empty?

  puts "#{category}:"
  clients.each{ |client| puts "  #{client}" }
end
