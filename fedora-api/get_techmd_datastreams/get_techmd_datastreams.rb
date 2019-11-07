# standard library
require 'logger'
require 'net/http'
require 'optparse'

# other dependencies
require 'bundler/inline'
gemfile do
  gem 'progressbar', '>= 1.10.1'
end


options = {}
OptionParser.new{ |opts|
  opts.banner = 'Usage: ruby get_techmd_datastreams.rb -p {local_port} -i {input_file} -o {output_directory}'

  opts.on('-p', '--port LOCALPORT', 'Local port number for access to Fedora server'){ |p|
    options[:port] = p
  }
  opts.on('-i', '--input INPUTFILE', 'Path to input file'){ |i|
    options[:input] = i
    unless File::exist?(i)
      puts "Not a valid input file: #{i}"
      exit
    end
  }
  opts.on('-o', '--output OUTPUTDIR', 'Path to output directory'){ |o|
    options[:output] = o
    unless Dir::exist?(o)
      puts "Not a valid input file: #{o}"
      exit
    end
  }
  opts.on('-h', '--help', 'Prints this help'){
    puts opts
    exit
  }
}.parse!

log = Logger.new("#{options[:output]}/get_techmd_datastreams.log")


  def get_pids(filepath)
    pids = []
    File.readlines(filepath).each{ |ln|
      pids << ln.chomp
    }
    return pids
  end


pids = get_pids(options[:input])

progress = ProgressBar.create(:title => "Processing", :starting_at => 0, :total => pids.length, :format => '%a %E %B %c %C %p%% %t')

pids.each{ |pid|
  outfile = "#{options[:output]}/#{pid.sub(':', '-')}.xml"
  next if File::exist?(outfile)
  url = URI("http://localhost:#{options[:port]}/fedora/objects/#{pid}/datastreams/TECHMD/content")
  result = Net::HTTP.get_response(url)
  if result.is_a?(Net::HTTPSuccess)
    File.open(outfile, 'w'){ |f|
      f.write result.body
    }
  else
    File.open("#{options[:output]}/errs.txt", 'a'){ |f|
      puts pid
    }
    log.error("Did not write datastream for #{pid}: #{result.code} #{result.message}")
  end
  progress.increment
  sleep 0.15
}

progress.finish
