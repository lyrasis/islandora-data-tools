puts 'Checking/installing dependencies...'

require 'bundler/inline'
require 'logger'
require 'optparse'
require 'pp'

gemfile do
  source 'https://rubygems.org'
  gem 'nokogiri', '~> 1.10.4'
  gem 'progressbar', '>= 1.10.1'
  gem 'pry'
end

# Path to default MODS schema to use for validation if a path is not passed in as an option
#   when the script is called
#
# This should work when script is run on the LYRASIS migration server. If run elsewhere, you
#   need to pass in the -s/--schema option when you run the script
SCHEMAPATH = '/opt/migrations/shared/mods/mods_3_7_schema.xsd'

options = {}
OptionParser.new{ |opts|
  opts.banner = 'Usage: ruby validate_mods_files_in_directory.rb -i {input_dir} -s {path/to/schema/file}'

  opts.on('-i', '--input INPUTDIR', 'Path to directory containing MODS files to process'){ |i|
    options[:input] = File.expand_path(i)
    unless Dir::exist?(i)
      puts "Not a valid input directory: #{i}"
      exit
    end
  }
  opts.on('-s', '--schema [SCHEMA]', 'Path to MODS schema file.'){ |s|
    if s.nil?
      options[:schema] = File.expand_path(SCHEMAPATH)
    elsif File.file?(File.expand_path(s))
      options[:schema] = File.expand_path(s)
    else
      puts "Schema file does not exist at: #{s}"
    end
  }
  opts.on('-h', '--help', 'Prints this help'){
    puts opts
    exit
  }
}.parse!

modspath = options[:input]
logpath = "#{modspath}/validation_log.txt"
log = Logger.new(logpath)

schemapath = options[:schema]
schemapath = SCHEMAPATH if schemapath.nil?
schema = Nokogiri::XML::Schema(File.open(schemapath))

modsfiles = Dir.new(modspath).children
  .select{ |f| f.end_with?('.xml')}
  .map{ |f| "#{modspath}/#{f}" }

errs = {}

puts "Validating #{modsfiles.length} MODS files in #{modspath}"
pb = ProgressBar.create(:starting_at => 0,
                        :total => modsfiles.length,
                        :format => '%a |%b>>%i| %p%% %t')

flag = 0
modsfiles.each{ |f|
  begin
    doc = Nokogiri::XML(File.read(f))
  rescue Nokogiri::XML::SyntaxError => err
    log.error("Parsing error: #{f}: #{err.message}")
    flag += 1
    pb.increment
    next
  end
  
  v = schema.validate(doc)
  if v.length == 0
    log.debug("MODS VALIDATION: valid MODS: #{f}")
  else
    v.each do |e|
      log.error("MODS VALIDATION: invalid MODS: #{f}: #{e}")
      errtext = e.message.sub(/^.*?ERROR: /, '')
      errs.key?(errtext) ? errs[errtext] += 1 : errs[errtext] = 1
    end
    flag += 1
  end
  pb.increment
}
pb.finish
if flag > 0
  puts "\n\n#{flag} invalid MODS files in #{modspath}. See validation_log.txt for details.\n"
  puts 'The unique error types found across the MODS files are:'
  errs.map{ |err, ct| [ct, err] }.sort.reverse.each{ |e| puts " - #{e.join("\t")}" }
end
