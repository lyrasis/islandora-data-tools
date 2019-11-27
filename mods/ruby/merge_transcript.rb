require 'bundler/inline'

# standard library
require 'json'
require 'pp'

# external helpers
gemfile do
  source 'https://rubygems.org'
  gem 'nokogiri', '~> 1.10.4'
end

=begin
Assumes directory structure like: 
 - /opt/migrations/client/{coll}
   - /opt/migrations/client/{coll}/mods-current
   - /opt/migrations/client/{coll}/cdm_metadata

Where: 
 - {coll} is the base directory for the CDM collection migration data
 - mods-current is a directory containing files of Islandora datastreams for 
    objects in the collection. File names = {Islandora PID}.xml
 - cdm_metadata is a directory containing JSON results of dmGetItemInfo for 
    objects in the collection. File names = {CDM pointer}.json

It also assumes there is a islandora_cdm_id_map.txt file (created with 
  map_islandora_CDM_ids.rb) in the base directory.

It will write revised MODS files to the directory specified as newdir
=end

# fill in the following variables as per the assumptions above
basedir = '/opt/migrations/client/coll'
modsdir = 'mods-current'
cdmdir = 'cdm_metadata'
newdir = 'mods-new'
coll = 'collalias'


Dir::chdir(basedir)
Dir::mkdir("#{basedir}/#{newdir}") unless Dir::exist?("#{basedir}/#{newdir}")

creatos = {}

File.open('islandora_cdm_id_map.txt', 'r').each { |idmap|
  ids = idmap.chomp.split("\t")
  pid = ids[0] #Islandora PID
  ptr = ids[1].sub('/id/', '').sub(coll, '')  #CDM pointer

  cfile = "#{basedir}/#{cdmdir}/#{ptr}.json"
  mfile = "#{basedir}/#{modsdir}/#{pid}.xml"
  nfile = "#{basedir}/#{newdir}/#{pid}.xml"
  
  crec = JSON.parse(File.read(cfile))
  mrec = Nokogiri::XML(File.read(mfile))
  
  transc = crec['transc']
  next if transc.is_a?(Hash)
  transc = transc.strip

  tnote = Nokogiri::XML::Node.new('note', mrec)
  tnote['displayLabel'] = 'Transcription'
  tnote['type'] = 'display_transcript'
  tnote.content = transc
  mrec.search('mods').each { |n| n.add_child(tnote) }

  File.open(nfile, 'w') { |f|
    f.write mrec.to_xml
  }
}

