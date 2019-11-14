# standard library
require 'optparse'
require 'pp'

#other dependencies
require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'
  gem 'nokogiri', '~> 1.10.4'
end

options = {}
OptionParser.new{ |opts|
  opts.banner = 'Usage: ruby cdm_islandora_id_map.rb -m {mods_dir}'

  opts.on('-m', '--input MODSDIR', 'Path to directory containing Islandora MODS files to process'){ |m|
    options[:modsdir] = m
    unless Dir::exist?(m)
      puts "Not a valid input directory: #{m}"
      exit
    end
  }
  opts.on('-h', '--help', 'Prints this help'){
    puts opts
    exit
  }
}.parse!


path_pieces = options[:modsdir].split('/')
# name of directory containing MODS
modsdir = path_pieces.pop
# working dir path
wdir = path_pieces.join('/')

Dir::chdir(wdir)
File.open('islandora_cdm_id_map.tsv', 'w'){ |outfile|
  Dir::each_child(modsdir) { |modsfile|
    mods = Nokogiri::XML(File.open("#{modsdir}/#{modsfile}"))
    idnode = mods.xpath("//mods:identifier[@type='CONTENTdm ID']").first
    i_id = modsfile.sub('.xml', '')
    outfile.write("#{i_id}\t#{idnode.text}\n")
  }
}
