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
modsdir = 'coll-output-mods_backup'
newdir = 'mods-new'

elements_to_split = [
#  { :element => "//mods:classification", :delim => '; ', :cap => true },
  { :element => "//mods:genre[@authority='local']", :delim => '; ', :cap => true },
#    { :element => "//mods:genre[@authority='local']", :delim => ', ', :cap => true },
#  { :element => "//mods:note[@displayLabel='Construction Type']", :delim => '; ', :cap => false },
  #  { :element => "//mods:note[@displayLabel='Name of Building']", :delim => '; ', :cap => false },
#  { :element => "//mods:originInfo/mods:publisher", :delim => '; ', :cap => false },
#  { :element => "//mods:physicalDescription/mods:form", :delim => '; ', :cap => false },
#  { :element => "//mods:subject[@authority='lcsh']/mods:geographic", :delim => '; ', :cap => false },
#  { :element => "//mods:subject[(@authority='lcsh') and (@displayLabel='Time Period')]/mods:temporal", :delim => '; ', :cap => false },
  { :element => "//mods:subject/mods:topic", :delim => '; ', :cap => false },
#  { :element => "//mods:subject/mods:name/mods:namePart", :delim => '; ', :cap => false },
  { :element => "//mods:typeOfResource", :delim => '; ', :cap => false },
#  { :element => "//mods:typeOfResource", :delim => ', ', :cap => false }
]

=begin
This is an array of xpath snippets to the multivalued elements, with two settings:
- delim: the delimiter
- cap: whether to capitalize the first character of each split value

Note:
- You have to include the relevant namespace prefix on each segment

To split any topic on ;
"//mods:topic" => { :delim => '; ', :cap => true }

Split only MeSH topics on ;
  "//mods:subject[@authority='mesh']/mods:topic" => { :delim => '; ', :cap => true }

Split only MeSH topics with display labels on ;
  "//mods:subject[(@authority='mesh') and (@displayLabel='Medical subject')]/mods:topic" => { :delim => '; ', :cap => true }

Split only MeSH topics without display labels on ;
  "//mods:subject[(@authority='mesh') and not(@displayLabel='Medical subject')]/mods:topic" => { :delim => '; ', :cap => true }

Split <typeOfResource>text; still image, moving image</typeOfResource> and do NOT capitalize
  "//mods:typeOfResource" => { :delim => '; ', :cap => false },
  "//mods:typeOfResource" => { :delim => ', ', :cap => false }
=end

def process_mods(doc, node, vals)
  case node.name
  when 'classification'
    return process_mods_same_level(doc, node, vals)
  when 'form'
    return process_mods_same_level(doc, node, vals)
  when 'genre'
    return process_mods_same_level(doc, node, vals)
  when 'geographic'
    return process_mods_second_level_from_top(doc, node, vals)
  when 'namePart'
    if node.parent.parent.name == 'subject'
      return process_mods_third_level_from_top(doc, node, vals)
    else
      return process_mods_second_level_from_top(doc, node, vals)
    end
  when 'note'
    return process_mods_same_level(doc, node, vals)
  when 'publisher'
    return process_mods_same_level(doc, node, vals)
  when 'temporal'
    return process_mods_second_level_from_top(doc, node, vals)
  when 'topic'
    return process_mods_second_level_from_top(doc, node, vals)
  when 'typeOfResource'
    return process_mods_same_level(doc, node, vals)
  else
    puts "WARNING: configure process_mods for field: #{node.name} and re-run script"
    return doc
  end
end

#Dir::chdir(basedir)
Dir::mkdir("#{basedir}/#{newdir}") unless Dir::exist?("#{basedir}/#{newdir}")

currentmodsdir = "#{basedir}/#{modsdir}"
modsfiles = Dir.new(currentmodsdir).children.select{ |child| child['.xml'] }

def has_multival(doc, to_split)
  needsplit = []
  to_split.each { |settings|
    element = settings[:element]
    nodeset = doc.xpath(element).select{ |n| n.text[settings[:delim]] }
    nodeset.each { |n| needsplit << n } if nodeset.length > 0
  }

  if needsplit.length > 0
    return true
  else
    return false
  end
end

def build_node(name, attr, home)
  node = Nokogiri::XML::Node.new(name, home)
  attr.each_value { |a|
    node[a.name] = a.value
  }
  return node
  end

def process_mods_same_level(doc, node, vals)
  vals.each { |val|
    svnode = build_node(node.name, node.attributes, doc)
    svnode.content = val
    node.add_next_sibling(svnode)
  }
  node.remove
  return doc
end

def process_mods_second_level_from_top(doc, node, vals)
  vals.each { |val|
    newtopnode = build_node(node.parent.name, node.parent.attributes, doc)
    svnode = build_node(node.name, node.attributes, doc)
    svnode.content = val
    newtopnode.add_child(svnode)
    node.parent.add_next_sibling(newtopnode)
  }
  node.parent.remove
  return doc
end

def process_mods_third_level_from_top(doc, node, vals)
  vals.each { |val|
    newtopnode = build_node(node.parent.parent.name, node.parent.parent.attributes, doc)
    newmidnode = build_node(node.parent.name, node.parent.attributes, doc)
    svnode = build_node(node.name, node.attributes, doc)
    svnode.content = val
    newtopnode.add_child(newmidnode)
    newmidnode.add_child(svnode)
    node.parent.parent.add_next_sibling(newtopnode)
  }
  node.parent.parent.remove
  return doc
end

def split_multival(doc, elements_to_split)
  elements_to_split.each { |settings|
    element = settings[:element]
    delim = settings[:delim]
    cap = settings[:cap]

    puts "   RESULTS FOR: #{element}"
    nodeset = doc.xpath(element).select{ |n| n.text[delim] }
    nodeset.each { |mvnode|
      pp(mvnode)
      vals = mvnode.text.split(delim).map{ |val| val.strip }
      vals.map!{ |val| val.sub(/^./, &:upcase) } if cap

      if mvnode.namespace.href['/mods/']
        doc = process_mods(doc, mvnode, vals)
      end
    }
  }
  return doc
end

modsfiles.each { |f|
  current_modsfile_path = "#{currentmodsdir}/#{f}"

  new_modsfile_path = "#{basedir}/#{newdir}/#{f}"
  doc = Nokogiri::XML(File.read(current_modsfile_path))  
  if has_multival(doc, elements_to_split)
    puts "RESULTS FOR: #{current_modsfile_path}"
    doc = split_multival(doc, elements_to_split)
    File.open(new_modsfile_path, 'w'){ |newfile| newfile.write(doc) }
  else
    next
  end
}
