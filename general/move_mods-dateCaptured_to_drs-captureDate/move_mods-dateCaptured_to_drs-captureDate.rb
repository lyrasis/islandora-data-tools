# standard library
require 'optparse'

# other dependencies
require 'bundler/inline'
gemfile do
  source 'https://rubygems.org'
  gem 'nokogiri', '>= 1.10.4'
  gem 'progressbar', '>= 1.10.1'
end

options = {}
OptionParser.new{ |opts|
  opts.banner = 'Usage: ruby list_invalid_or_malformed_objs.rb -i {input_dir}'

  opts.on('-i', '--input INPUTDIR', 'Path to directory containing MODS files to process'){ |i|
    options[:input] = i
    unless Dir::exist?(i)
      puts "Not a valid input directory: #{i}"
      exit
    end
  }
  opts.on('-o', '--output OUTPUTDIR', 'Path to directory in which to save revised MODS files'){ |o|
    options[:output] = o
    unless Dir::exist?(o)
      Dir::mkdir(o)
    end
  }
  opts.on('-h', '--help', 'Prints this help'){
    puts opts
    exit
  }
}.parse!

indir = Dir.new(options[:input])
inmods = indir.children.select{ |filename| filename.end_with?('.xml') }

progress = ProgressBar.create(:title => "Processing", :starting_at => 0, :total => inmods.length, :format => '%a %E %B %c %C %p%% %t')

def build_node(name, attr, home)
  node = Nokogiri::XML::Node.new(name, home)
  attr.each_value { |a|
    node[a.name] = a.value
  }
  return node
  end

inmods.each{ |mods|
  progress.increment
  rec = Nokogiri::XML(File.read("#{options[:input]}/#{mods}"), &:noblanks)
  rec.root.add_namespace_definition('drs', 'info://lyrasis/drs-admin/v1')
  
  extension = Nokogiri::XML::Node.new('extension', rec)
  admin = Nokogiri::XML::Node.new('drs:admin', rec)
  extension.add_child(admin)
  
  dateCaps = rec.xpath("//mods:dateCaptured")
  dateCaps.each{ |dateCap|
    dcnode = build_node('drs:captureDate', dateCap.attributes, rec)
    dcnode.content = dateCap.text
    admin.add_child(dcnode)
    dateCap.remove
  }

  rec.root.add_child(extension)
  File.open("#{options[:output]}/#{mods}", 'w'){ |f| f.write(rec.to_xml( indent:2, indent_text:" ")) }
}

progress.finish
