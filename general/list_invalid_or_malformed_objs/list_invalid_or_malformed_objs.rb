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
  opts.banner = 'Usage: ruby list_invalid_or_malformed_objs.rb -i {input_dir}'

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

log = Logger.new("#{options[:input]}/_results.log")

dir = Dir.new(options[:input])
datastreams = dir.children.select{ |filename| filename.end_with?('.xml') }

progress = ProgressBar.create(:title => "Processing", :starting_at => 0, :total => datastreams.length, :format => '%a %E %B %c %C %p%% %t')

def compile_elements(doc, xpath)
  arr = []
  REXML::XPath.each(doc, xpath){ |e| arr << e.text }
  arr.uniq! if arr.length > 0
  return arr
end

def get_status(arr)
  return true if arr == ['true']
  return false if arr == ['false']
  return 'conflict' if arr.sort == ['false', 'true']
  return nil if arr == []
end

def get_mimetype(doc)
  id = REXML::XPath.first(doc, "//identification/identity")
  return id.attributes['mimetype'] if id
  return 'no mimetype' if !id
end

def translate_status(status, type)
  return "#{type}:conflict" if status == 'conflict'
  return "#{type}:t" if status == true
  return "#{type}:f" if status == false
  return "#{type}:noinfo" if status.nil?
end

datastreams.each{ |datastream|
  progress.increment
  ds = REXML::Document.new(File.read("#{options[:input]}/#{datastream}"))
  pid = datastream.sub('-', ':').sub('.xml', '')

  wf = get_status(compile_elements(ds, "//filestatus/well-formed"))
  valid = get_status(compile_elements(ds, "//filestatus/valid"))

  writeout = "#{pid}\t#{get_mimetype(ds)}\t#{translate_status(wf, 'wf')}\t#{translate_status(valid, 'valid')}"

  if wf == true && valid == true
    log.info(writeout)
  elsif ( wf == true && valid == 'conflict' ) || ( wf == 'conflict' && valid == true )
    log.warn(writeout)
  elsif wf == false || valid == false
    log.error(writeout)
  elsif wf.nil? || valid.nil?
    log.unknown(writeout)
  else
    log.debug(writeout)
  end
}

progress.finish
