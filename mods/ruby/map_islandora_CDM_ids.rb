require 'bundler/inline'
require 'pp'

gemfile do
  source 'https://rubygems.org'
  gem 'nokogiri', '~> 1.10.4'
end

# path to directory containing Islandora MODS files (datastreams downloaded, with filenames = PID.xml)
modspath = '/opt/migrations/client/coll/mods-current'
path_pieces = modspath.split('/')
# name of directory containing MODS
modsdir = path_pieces.pop
# working dir path
wdir = path_pieces.join('/')

Dir::chdir(wdir)
File.open('islandora_cdm_id_map.txt', 'w'){ |outfile|
  Dir::each_child(modsdir) { |modsfile|
    mods = Nokogiri::XML(File.open("#{modsdir}/#{modsfile}"))
    idnode = mods.xpath("//mods:identifier[@type='CONTENTdm ID']").first
    i_id = modsfile.sub('.xml', '')
    outfile.write("#{i_id}\t#{idnode.text}\n")
  }
}
