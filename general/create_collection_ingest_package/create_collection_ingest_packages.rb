# The goal of this script is to create a collection ingest package using
# a CSV with collection name and description, a MODS template, a COLLECTION_POLICY
# template, and a thumbnail image

require 'csv'
require 'nokogiri'

# Loops through a CSV with collection name and description to create an
# ingest package

# Assumes CSV has no headers
coll_descs = get_csv('/Users/jshelby/Documents/migrations/islandora/ncm/data/source','islandora_collectionsdescriptions.csv')

parent_dir = 'collections_ingest_package'
parent_path = File.join(File.expand_path("."),parent_dir)

mkdir(File.expand_path("."),parent_dir)

folder_num = 1

coll_descs.each do |record|
  # Creates a subdirectory for each collection
  coll_dir = "coll_#{folder_num}"
  puts "Processing #{coll_dir}"
  coll_path_dir = File.join(parent_path,coll_dir)
  mkdir(parent_path,coll_dir)
  folder_num += 1

  # Assumes COLLECTION_POLICY.xml and TN.jpg are in the script's directory
  cp(File.join(File.expand_path("."),'COLLECTION_POLICY.xml'),coll_path_dir)
  cp(File.join(File.expand_path("."),'TN.jpg'),coll_path_dir)

  # Copies and modifies the MODS_template to insert the collection's name and description
  mods_template = get_mods(File.expand_path("."),'MODS.xml')
  modified_mods = create_coll_mods(mods_template,record)
  save_mods(modified_mods,coll_path_dir,'MODS.xml')
end

## All the methods
## BEGIN loads the methods before the above script
BEGIN {
  # Copies file one from place to another
  def cp(path_from,path_to)
    `cp #{path_from} #{path_to}`
  end

  # Creates a directory
  def mkdir(path,dir_name)
    `mkdir #{File.join(path,dir_name)}`
  end

  # Returns an array of arrays
  def get_csv(path,file)
    CSV.read(File.join(path,file), encoding:'utf-8')
  end

  # Returns a Nokogiri object with MODs data
  def get_mods(path,file)
    File.open(File.join(path,file)) { |f| Nokogiri::XML(f) }
  end

  # Hard-inserts fields from record into mods_template
  # returns Nokogiri::XML object
  # mods_template: Nokogiri::XML object
  # record: array of field values
  def create_coll_mods(mods_template,record)
    title = mods_template.at_css "title"
    title.content = record[0]

    abstract = mods_template.at_css "abstract"
    abstract.content = record[1]

    mods_template
  end

  # Saves MODS XML to a file
  def save_mods(mods,path,file)
    filename = File.join(path,file)

    File.write(filename,mods)
  end
}