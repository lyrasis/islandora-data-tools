# standard library
require 'optparse'
require 'pp'

options = {}
OptionParser.new{ |opts|
  opts.banner = 'Usage: ruby rename_cdm_thumbnails.rb -c COLL -m MAP_PATH -t TN_PATH'

  opts.on('-c', '--coll COLL', 'CDM collection alias for the collection being processed'){ |c|
    options[:coll] = c
  }
  opts.on('-m', '--map MAP_PATH', 'Full path to islandora_cdm_id_map.tsv for the collection'){ |m|
    options[:mappath] = m
    unless File::exist?(m)
      puts "File does not exist: #{m}"
      exit
    end
  }
  opts.on('-t', '--thumbs TN_PATH', 'Full path to directory containing CDM thumbnails for the collection'){ |t|
    options[:tnpath] = t
    unless Dir::exist?(t)
      puts "Directory does not exist: #{t}"
      exit
    end
  }
  opts.on('-h', '--help', 'Prints this help'){
    puts opts
    exit
  }
}.parse!

def create_map(mappath, coll)
  h = {}

  File.readlines(mappath).each{ |ln|
    ids = ln.chomp.split("\t")
    iid = ids[0].sub(':', '-')
    cid = ids[1].sub("#{coll}/id/", '')
    h[cid] = iid
  }
  return h
end

id_map = create_map(options[:mappath], options[:coll])

to_rename = Dir.new(options[:tnpath]).children

to_rename.each{ |f|
  find = File.basename(f, ".jpg")
  replace = id_map[find]
  if replace
    File.rename("#{options[:tnpath]}/#{f}", "#{options[:tnpath]}/#{replace}.jpg")
  else
    puts "WARNING: cannot rename #{f}"
  end    
}

