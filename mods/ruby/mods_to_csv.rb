require 'csv'
require 'logger'
require 'optparse'
require 'pp'

require 'bundler/inline'
gemfile do
  source 'https://rubygems.org'
  gem 'nokogiri', '>= 1.10.4'
end

Log = Logger.new(STDOUT)

=begin
ABOUT CONFIG

Each top level key of the hash is an element on which you want a new row to be created.

If example MODS includes:

<mods:physicalDescription>
  <mods:note>PD 1, Note 1</mods:note>
  <mods:note>PD 1, Note 2</mods:note>
</mods:physicalDescription>
<mods:physicalDescription>
  <mods:note>PD 2, Note 1</mods:note>
  <mods:note>PD 2, Note 2</mods:note>
</mods:physicalDescription>

And config hash includes:

'mods:physicalDescription' => {
  'mods:note' => ['value']
}

You will get the following rows:

PD 1, Note 1; PD 1, Note 2
PD 2, Note 1; PD 2, Note 2

If the config hash includes:

'mods:physicalDescription/mods:note' => {
  'self' => ['value']
}

You will get the following rows:

PD 1, Note 1
PD 1, Note 2
PD 2, Note 1
PD 2, Note 2

As a second-level key, 'self' means you want the value of the row-splitting node AND/OR
the value(s) of attribute(s) of the row-splitting node.

As a second-level array element, 'value' returns the value of the node. An attribute (with @
prefix) returns the value of that attribute on that node.
=end

config = {
   # 'mods:titleInfo' => {
   #   'self' => ['@type', '@usage'],
   #   'mods:title' => ['value']
   # },
   # 'mods:relatedItem' => {
   #   'mods:titleInfo/mods:title' => ['value']
   # },
   # 'mods:originInfo/mods:dateCreated' => {
   #   'self' => ['value', '@keyDate', '@qualifier', '@encoding', '@point']
   # },
   'mods:originInfo/mods:dateIssued' => {
     'self' => ['value', '@keyDate', '@qualifier', '@encoding', '@point']
   },
 }

options = {}
OptionParser.new{ |opts|
  opts.banner = 'Usage: ruby mods_to_csv.rb -m {mods_directory} -c {csv_path}'

  opts.on('-m', '--modsdir path_to_modsdir', 'Path to directory containing MODS files'){ |m|
    options[:modsdir] = m
  }
  opts.on('-c', '--csvpath path_to_csv ', 'Path to output CSV file'){ |c|
    options[:csvpath] = c
  }

}.parse!

mods_files = Dir.children(File.expand_path(options[:modsdir])).select{ |name| name['.xml'] }

def make_headers(config)
  headers = ['id']
  config.each{ |relement, colhash|
    hdr = relement.clone.sub('//', '').gsub('mods:', ' ')
    colhash.each{ |element, columns|
      if element == 'self'
        ehdr = hdr
      else
        hdrelement = element.clone.gsub('mods:', ' ')
        ehdr = hdr + hdrelement
      end
      columns.each{ |column|
        if column == 'value'
          chdr = ehdr
        else
          chdr = ehdr + ' ' + column
        end
        headers << chdr.sub('/', '').strip
      }
    }
  }
  headers << 'sort'
  return headers
end

def extract_mods(modspath, modsfile, xpaths)
  id = modsfile.sub('.xml', '')

  begin
    doc = Nokogiri::XML(File.open("#{modspath}/#{modsfile}"))
  rescue
    Log.warn("#{modsfile} - Empty XML document")
    return {id => []}
  end
  
  mods = doc.root

  # The following line is needed because it looks like the mods namespace hasn't been
  #  defined in the standard way for all our clients
  mods.add_namespace_definition('mods', 'http://www.loc.gov/mods/v3') unless mods.namespaces.has_key?('xmlns:mods')
  modsdata = []
  xpaths.each{ |relement, colhash|
    hdr = relement.clone.sub('//', '').gsub('mods:', ' ')
    rownodes = mods.xpath(relement)
    if rownodes.length > 0
    rownodes.each{ |rownode|
      modsdata << process_row(rownode, colhash, hdr)
    }
    else
      blank = Nokogiri::XML::Element.new('blank', doc)
      modsdata << process_row(blank, colhash, hdr)
    end
  }
  return {id => modsdata}
end

def process_row(rownode, colhash, hdr)
  colvals = {}
  
  colhash.each{ |element, columns|
    unless element == 'self'
      hdrelement = element.clone.gsub('mods:', ' ')
      hdr = hdr + hdrelement
    end

    if element == 'self'
      nodes = rownode
    else
      nodes = rownode.xpath(element)
    end

    columns.each{ |column|
      vals = get_column_values(column, nodes, hdr)
      colvals[vals[0]] = vals[1]
    }
  }
  return colvals
end

def get_column_values(column, rownodes, hdr)
  hdr = hdr + ' ' + column unless column == 'value'

  if column == 'value'
    if rownodes.is_a?(Nokogiri::XML::NodeSet)
      values = rownodes.map{ |node| node.text }
    else
      values = [rownodes.text]
    end
  else
    attr = column.sub('@', '')
    values = []
    if rownodes.is_a?(Nokogiri::XML::NodeSet)
      rownodes.each{ |node|
        if node.attribute(attr)
          values << node.attribute(attr).value
        else
          values << ['']
        end
      }
    else
      rownodes.attribute(attr) ? values << rownodes.attribute(attr).value : values << ''
    end
  end

  return [hdr.sub('/', '').strip, values.join(';;; ')]
end


header =  make_headers(config)
CSV.open(options[:csvpath], 'wb'){ |csv|
  csv << header
  ct = 1
  mods_files.each{ |modsfile|
    extract_mods(options[:modsdir], modsfile, config).each{ |id, rowarr|
      rowarr.each{ |rhash|
        row = CSV::Row.new(header, [])
        row['id'] = id
        rhash.each{ |header, value| row[header] = value }
        row['sort'] = ct
        csv << row
        ct += 1
      }
    }
  }
}

