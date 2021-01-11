# standard library
require 'optparse'

# other dependencies
require 'bundler/inline'
gemfile do
  source 'https://rubygems.org'
  gem 'nokogiri', '>= 1.10.4'
  gem 'progressbar', '>= 1.10.1'
  gem 'pry'
end

options = {}
OptionParser.new{ |opts|
  opts.banner = 'Usage: ruby remove_blank_attributes.rb -i {input_dir} -o {output_dir}'

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

inmods.each{ |mods|
  progress.increment

  begin
    doc = Nokogiri::XML(File.read("#{options[:input]}/#{mods}"), &:noblanks)
  rescue Nokogiri::XML::SyntaxError => err
    puts "Skipping due to parsing error: #{f}: #{err.message}"
    next
  end

  doc.traverse do |node|
    unless node.keys.empty?
      node.attributes.each do |attr|
        node.delete(attr[0]) if attr[1].value.empty?
      end
    end
  end
  File.open("#{options[:output]}/#{mods}", 'w'){ |f| f.write(doc.to_xml( indent:2, indent_text:" ")) }
}

progress.finish
