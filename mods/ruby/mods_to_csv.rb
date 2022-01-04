require 'csv'
require 'logger'
require 'optparse'
require 'pp'

require 'bundler/inline'
gemfile do
  source 'https://rubygems.org'
  gem 'progressbar', '>= 1.10.1'
  gem 'nokogiri', '>= 1.10.4'
  gem 'pry', '>= 0.13.0'
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
  # 'mods:accessCondition'=> {
  #   'self' => ['value', '@type', '@displayLabel', '@altRepGroup', '@altFormat', '@contentType', '@xlink:href',
  #              '@lang', '@xml:lang', '@script', '@transliteration']
  # },

  'mods:extension/drs:admin/drs:captureDate' => {
    'self' => ['value']
  },
  
  # 'mods:extension/etd:degree' => {
  #   'etd:name' => ['value'],
  #   'etd:level' => ['value'],
  #   'etd:discipline' => ['value']
  # },

  # 'mods:location'=> {
  #   'mods:holdingSimple/mods:copyInformation/mods:subLocation' => ['value'],
  #   'mods:physicalLocation' => ['@type', 'value']
  # },

  # 'mods:note'=> {
  #   'self' => ['@type', '@displayLabel', '@xlink:href']
  # },

  'mods:note[@type="date/sequential_designation"]'=> {
    'self' => ['value']
  },

  'mods:note[@type="date/sequential designation"]'=> {
    'self' => ['value']
  },

  # 'mods:originInfo' => {
  #   'self' => ['@eventType'],
  #   'mods:copyrightDate' => ['@encoding', 'value'],
  #   'mods:dateCaptured' => ['@encoding', '@keyDate', 'value'],
  #   'mods:dateCreated' => ['@encoding', '@keyDate', '@point', '@qualifier', 'value'],
  #   'mods:dateIssued' => ['@encoding', '@keyDate', '@point', '@qualifier', 'value'],
  #   'mods:dateOther' => ['@encoding', '@keyDate', '@qualifier', 'value'],
  #   'mods:dateModified' => ['value'],
  #   'mods:dateValid' => ['value'],
  #   'mods:edition' => ['value'],
  #   'mods:frequency' => ['@authority', 'value'],
  #   'mods:issuance' => ['value'],
  #   'mods:place/mods:placeTerm' => ['@authority', '@type', 'value'],
  #   'mods:publisher' => ['value']
  # },

  # 'mods:originInfo/mods:place/mods:placeTerm' => {
  #   'self' => ['@authority', '@type', 'value']
  # },

  'mods:originInfo/mods:dateCreated' => {
    'self' => ['value', '@keyDate', '@qualifier', '@encoding', '@point']
  },

  'mods:originInfo/mods:dateIssued' => {
    'self' => ['value', '@keyDate', '@qualifier', '@encoding', '@point']
  },

  'mods:originInfo/mods:dateOther' => {
    'self' => ['value', '@type', '@keyDate', '@qualifier', '@encoding', '@point']
  },

  # 'mods:part'=>{
  #   'mods:detail'=>['@type', '@level', 'value of mods:number', 'value of mods:caption', 'value of mods:title'],
  #   'mods:extent'=>['@unit', 'value of mods:start', 'value of mods:end', 'value of mods:total', 'value of mods:list'],
  #   'mods:date'=>['value'],
  #   'mods:text'=>['@type', '@displayLabel', 'value']
  # },

  # 'mods:physicalDescription/mods:form'=>{
  #   'self'=>['@authority', '@type', 'value']
  # },

  'mods:recordInfo/mods:recordChangeDate' => {
    'self' => ['value', '@keyDate', '@qualifier', '@encoding', '@point']
  },

  'mods:recordInfo/mods:recordCreationDate' => {
    'self' => ['value', '@keyDate', '@qualifier', '@encoding', '@point']
  },

  # 'mods:relatedItem' => {
  #   'mods:titleInfo/mods:title' => ['value']
  # },

  # 'mods:relatedItem/mods:titleInfo' => {
  #   'self' => ['@displaylabel', '@lang', '@script', '@transliteration', '@type', 'value of mods:nonSort', 'value of mods:title', 'value of mods:subTitle', 'value of mods:partNumber', 'value of mods:partName'],
  # },

  # 'mods:relatedItem' => {
  #   'self' => ['@type', '@displayLabel'],
  #   'mods:identifier' => ['@type', 'value'],
  #   'mods:internetMediaType' => ['value'],
  #   'mods:location/mods:url' => ['@displayLabel', 'value'],
  #   'mods:name' => ['@type'],
  #   'mods:name/mods:namePart' => ['@type', 'value'],
  #   'mods:originInfo/mods:publisher' => ['value'],
  #   'mods:titleInfo/mods:title' => ['value'],
  #   'mods:titleInfo/mods:partName' => ['value'],
  # },

  # 'mods:subject' => {
  #   'self' => ['@authority'],
  #   'mods:genre' => ['value'],
  #   'mods:geographic' => ['value'],
  #   'mods:name' => ['@authority', '@type', '@valueURI'],
  #   'mods:name/mods:namePart' => ['@type', 'value'],
  #   'mods:name/mods:role/mods:roleTerm' => ['@authority', '@type', 'value'],
  #   'mods:occupation' => ['value'],
  #   'mods:temporal' => ['value'],
  #   'mods:titleInfo' => ['value'],
  #   'mods:topic' => ['value']
  # },

  # 'mods:titleInfo' => {
  #   'self' => ['@altRepGroup', '@authority', '@displaylabel', '@lang', '@nameTitleGroup', '@script', '@transliteration', '@type',
  #              '@usage', 'value of mods:nonSort', 'value of mods:title', 'value of mods:subTitle', 'value of mods:partNumber',
  #              'value of mods:partName'],
  #   'mods:title' => ['value']
  # },
}

options = {}
OptionParser.new{ |opts|
  opts.banner = 'Usage: ruby mods_to_csv.rb -d {mods_directory} -c {csv_path} -m 1'

  opts.on('-d', '--modsdir path_to_modsdir', 'Path to directory containing MODS files'){ |d|
    options[:modsdir] = d
  }
  opts.on('-c', '--csvpath path_to_csv ', 'Path to output CSV file'){ |c|
    options[:csvpath] = c
  }
  opts.on('-m', '--min INT', 'Minimum number of occurrences to report'){ |m|
    options[:min_occs] = m.to_i
  }
}.parse!

def make_headers(config)
  headers = ['client', 'id', 'occurrences']
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
        elsif column.start_with?('value of ')
          chdr = ehdr + ' ' + column.sub('value of mods:', '')
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

def open_mods(modspath, modsfile)
  begin
    doc = Nokogiri::XML(File.open("#{modspath}/#{modsfile}"))
  rescue
    Log.warn("#{modsfile} - Empty XML document")
    return {id => []}
  end
  
  doc.root
end

def fix_namespace_definitions(mods)





namespaces = {
    'dc' => 'http:://purl.org/elements/1.1/',
    'dcterms' => 'http://purl.org/dc/terms/',
    'drs' => 'info://lyrasis/drs-admin/v1',
    'dwc' => 'http://rs.tdwg.org/dwc/terms/',
    'edm' => 'http://pro.europeana.eu/edm-documentation',
    'etd' => 'http://www.ndltd.org/standards/metadata/etdms/1.0',
    'mods' => 'http://www.loc.gov/mods/v3',
    'xlink' => 'http://www.w3.org/1999/xlink',
    'xsi' => 'http://www.w3.org/2001/XMLSchema-instance'
  }

  namespaces.each do |ns, uri|
    next if mods.namespaces.has_key?("xmlns:#{ns}")

    begin
      mods.add_namespace_definition(ns, uri)
    rescue
      Log.warn("#{modsfile} - Cannot add #{ns.upcase} namespace definition. Check it out?")
    end
  end

  mods
end


def extract_mods(modspath, modsfile, config)
  id = modsfile.sub('.xml', '')

  mods = open_mods(modspath, modsfile)

  # The following line is needed because it looks like the mods namespace hasn't been
  #  defined in the standard way for all our clients
  mods = fix_namespace_definitions(mods)
  
  modsdata = []
  config.each{ |row_element, colhash|
    hdr = row_element.clone.sub('//', '').gsub(/(mods|etd):/, ' ')

    rownodes = mods.xpath(row_element)
    if rownodes.length > 0
      rownodes.each{ |rownode|
        modsdata << process_row(rownode, colhash, hdr)
      }
    else
      # blank = Nokogiri::XML::Element.new('blank', doc)
      # modsdata << process_row(blank, colhash, hdr)
    end
  }
  return {id => modsdata}
end

def process_row(rownode, colhash, hdr)
  colvals = {}
  
  colhash.each{ |element, columns|
    if element == 'self'
      ehdr = hdr
    else
      hdrelement = element.clone.gsub('mods:', ' ')
      ehdr = hdr + hdrelement
    end

    if element == 'self'
      nodes = rownode
    else
      nodes = rownode.xpath(element)
    end

    columns.each{ |column|
      vals = get_column_values(column, nodes, ehdr)
      colvals[vals[0]] = vals[1]
    }
  }
  return colvals
end

def get_column_value(rownodes)
    if rownodes.is_a?(Nokogiri::XML::NodeSet)
      return rownodes.map{ |node| node.text }
    else
      return [rownodes.text]
    end
end

def get_column_values(column, rownodes, hdr)
  if column == 'value'
    values = get_column_value(rownodes)
  elsif column.start_with?('value of')
    path = column.sub('value of ', '')
    hdr = hdr + ' ' + path.sub('mods:', '')
    if rownodes.is_a?(Nokogiri::XML::NodeSet)
      values = rownodes.map{ |node| node.xpath(path).text }
    else
      values = [rownodes.xpath(path).text]
    end
  else
    hdr = hdr + ' ' + column
    attr = column.sub('@', '')

    if attr[':']
      attr = attr.split(':')
      if rownodes.namespaces.keys.include?("xmlns:#{attr[0]}")
        ns = rownodes.namespaces["xmlns:#{attr[0]}"]
      else
        attr = attr.join(':')
      end
    end
    
    values = []
    if rownodes.is_a?(Nokogiri::XML::NodeSet)
      rownodes.each{ |node|
        if node.attribute(attr)
          if attr == 'xml:lang'
            values << node.lang
          elsif attr.is_a?(String)
            values << node.attribute(attr).value
          else
            values << node.attribute_with_ns(attr[1], ns)
          end
        else
          values << ['']
        end
      }
    else
      if attr == 'xml:lang'
        values << rownodes.lang
      elsif attr.is_a?(String)
        rownodes.attribute(attr) ? values << rownodes.attribute(attr).value : values << ''
      else
        rownodes.attribute_with_ns(attr[1], ns) ? values << rownodes.attribute_with_ns(attr[1], ns).value : values << ''
      end
    end
  end

  return [hdr.sub('/', '').strip, values.join(';;; ')]
end

def get_client(id)
  id.split(/[-:]/).first
end


mods_files = Dir.children(File.expand_path(options[:modsdir])).select{ |name| name['.xml'] }
file_count = mods_files.length

puts "Compiling from #{file_count} files\n"
progress = ProgressBar.create(:starting_at => 0,
                              :total => file_count,
                              :format => '%a |%b>>%i| %p%% %t')

ct = 0

header =  make_headers(config)
CSV.open(options[:csvpath], 'wb'){ |csv|
  csv << header
  mods_files.each{ |modsfile|
    extract_mods(options[:modsdir], modsfile, config).each{ |id, rowarr|
      next if rowarr.length < options[:min_occs]
      rowarr.each{ |rhash|
        ct += 1
        row = CSV::Row.new(header, [])
        row['id'] = id
        client = get_client(id)
        row['client'] = client
        row['occurrences'] = rowarr.length
        rhash.each{ |header, value| row[header] = value }
        row['sort'] = "#{client}-#{ct.to_s.rjust(9, '0')}"
        csv << row
      }
    }
    progress.increment
  }
}
progress.finish
puts "Extracted #{ct} rows.\n\n"
