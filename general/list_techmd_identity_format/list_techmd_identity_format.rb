# standard library
require 'logger'
require 'net/http'
require 'optparse'
require 'rexml/document'

# other dependencies
require 'bundler/inline'
gemfile do
  gem 'progressbar', '>= 1.10.1'
end


options = {}
OptionParser.new{ |opts|
  opts.banner = 'Usage: ruby list_techmd_identity_format.rb -i {input_dir}'

  opts.on('-i', '--input INPUTDIR', 'Path to input directory'){ |i|
    options[:input] = i
    unless Dir::exist?(i)
      puts "Not a valid input directory: #{i}"
      exit
    end
  }
  opts.on('-h', '--help', 'Prints this help'){
    puts opts
    exit
  }
}.parse!

log = Logger.new("#{options[:input]}/_techmd_identity_formats.log")

dir = Dir.new(options[:input])
datastreams = dir.children.select{ |filename| filename.end_with?('.xml') }

progress = ProgressBar.create(:title => "Processing", :starting_at => 0, :total => datastreams.length, :format => '%a %E %B %c %C %p%% %t')

def compile_elements(doc, xpath)
  arr = []
  REXML::XPath.each(doc, xpath){ |e| arr << e['format'] }
  arr.uniq! if arr.length > 0
  return arr
end

datastreams.each{ |datastream|
  progress.increment
  ds = REXML::Document.new(File.read("#{options[:input]}/#{datastream}"))
  pid = datastream.sub('-', ':').sub('.xml', '')

  msgs = compile_elements(ds, "//identity")

  if msgs.length > 0
    log.info("#{pid}\t#{msgs.join('; ')}")
  else
    log.warn("#{pid}\tNo identity element")
  end
}

progress.finish
