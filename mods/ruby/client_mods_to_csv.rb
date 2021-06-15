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
  opts.banner = 'Usage: ruby client_mods_to_csv.rb -c {clientfile} -m {modsdir} -o {outputfile} --minoccs {integer}'

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
  opts.on('-o', '--output STRING', 'REQUIRED: Path to directory in which to write output file.'){ |o|
    Dir::mkdir(o) unless Dir::exist?(o)	
    options[:output] = File.expand_path(o)
  }
  opts.on('--minoccs INTEGER', 'REQUIRED: Minimum number of occurrences per record to trigger writing to output. Use 1 if you want everything'){ |i|
    options[:minoccs] = i
  }
  opts.on('-h', '--help', 'Prints this help'){
    puts opts
    exit
  }
}
begin
  optparse.parse!
  required = %i[clients mods output minoccs]
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
  modsdir = "#{options[:mods]}/#{client}_clean"
  if Dir::exist?(modsdir)
    puts "Compiling #{client}..."
    cmd = "ruby mods_to_csv.rb -d #{modsdir} -c #{options[:output]}/#{client}.csv -m #{options[:minoccs]}"
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
  cmd = "cat #{options[:output]}/*.csv > #{options[:output]}/all_tmp.csv"
  system(cmd)

  rowct = 0
  CSV.open("#{options[:output]}/all.csv", 'wb', headers: true) do |csv|
    CSV.foreach("#{options[:output]}/all_tmp.csv", headers: true) do |row|
      rowct += 1
      csv << row.headers if rowct == 1
      csv << row unless row['id'] == 'id'
    end
  end

  Pathname.new(options[:output]).children.each{ |pathname| FileUtils.rm(pathname) unless pathname.basename.to_s == 'all.csv' }
end
