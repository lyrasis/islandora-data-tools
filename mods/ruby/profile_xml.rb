require 'bundler/inline'
require 'csv'
require 'fileutils'
require 'json'
require 'logger'
require 'optparse'
require 'pp'

gemfile do
  source 'https://rubygems.org'
  gem 'nokogiri', '~> 1.10.4'
  gem 'progressbar', '>= 1.10.1'
  gem 'pry'
  gem 'facets', require: false
end

options = {}
OptionParser.new{ |opts|
  opts.banner = 'Usage: ruby profile_xml.rb -i {input_dir}'

  opts.on('-i', '--input INPUTDIR', 'Path to directory containing XML files to process'){ |i|
    options[:input] = File.expand_path(i)
    unless Dir::exist?(i)
      puts "Not a valid input directory: #{i}"
      exit
    end
  }
  opts.on('-s', '--strip STRING', 'comma-delimited string indicating node(s) to strip from beginning of xpaths'){ |s|
    options[:strip] = s.split(',')
  }
  opts.on('-d', '--delimiter STRING', 'Column delimiter/separator for the output value files'){ |d|
    options[:delim] = d
  }
  opts.on('-h', '--help', 'Prints this help'){
    puts opts
    exit
  }
}.parse!

PROFILEPATH = "#{options[:input]}/profile"
VALUESPATH = "#{PROFILEPATH}/values"
FileUtils.mkdir_p(PROFILEPATH) unless Dir::exist?(PROFILEPATH)
FileUtils.mkdir_p(VALUESPATH) unless Dir::exist?(VALUESPATH)
FileUtils.rm_rf(Dir.glob("#{VALUESPATH}/*"))
logpath = "#{PROFILEPATH}/profile_log.txt"
LOG = Logger.new(logpath)
WRITE_CHECK_THRESHOLD = 2
BATCH_WRITE_THRESHOLD = 5

class ProfilingManager
  attr_reader :file_count, :err_count, :profile
  def initialize(dir:, strip:, delim:)
    @dir = dir
    @strip = strip ? strip : []
    @delim = delim
    @files = get_files
    @file_count = @files.length
    @err_count = 0
    @profile = {}
    @write_counts = {}
  end

  def process
    puts "Profiling #{file_count} files\n\n"
    progress = ProgressBar.create(:starting_at => 0,
                                  :total => file_count,
                                  :format => '%a |%b>>%i| %p%% %t')
    puts ''

    @files.each do |file|
      fileprofiler = FileProfiler.new(xml: get_doc(file), path: file)
      merge_file_profile(fileprofiler)
      progress.increment
      write_values_over_threshold if progress.progress.modulo(WRITE_CHECK_THRESHOLD) == 0
    end
    progress.finish
    puts 'Post-processing and reporting...'
    @profile.each{ |xpath, valhash| write_values(xpath, valhash) }
    [@profile, @write_counts].each{ |hash| clean_xpaths(hash) }
    @profile.transform_values!{ |hash|{ occs: hash[:occurrences], uniqs: 0 } }
    deduplicate_value_files
    generate_stats
    rename_tmp_files
    add_headers
  end

  def report_summary
    occlabel = 'OCCURRENCES'
    uniqlabel = 'UNIQUES'
    puts "      \t#{occlabel}\t#{uniqlabel}\tXPATH"
    @profile.keys.sort.each do |xpath|
      target = @profile[xpath]
      occs = target[:occs]
      uniqs = target[:uniqs]
      occ = occs.to_s.rjust(occlabel.length, ' ')
      uniq = uniqs.to_s.rjust(uniqlabel.length, ' ')
      puts "#{label(uniqs, occs)}\t#{occ}\t#{uniq}\t#{xpath}"
    end
  end

  private

  def add_headers
    Pathname.new(VALUESPATH).each_child{ |filepath| add_header_to_file(filepath) }

    # get rid of files without headers
    Pathname.new(VALUESPATH).each_child do |filepath|
      FileUtils.rm(filepath) if filepath.to_s.end_with?('.txt')
    end

    # rename files with headers
    Pathname.new(VALUESPATH).each_child do |filepath|
      FileUtils.mv(filepath, filepath.sub('_with_header', ''))
    end
end

  def add_header_to_file(filepath)
    new_path = "#{filepath}_with_header"
    File.open(new_path, 'w') do |with_hdr|
      write_row(with_hdr, headers)

      File.foreach(filepath) do |row|
        with_hdr.write(row)
      end
    end
  end
  

  def rename_tmp_files
    Pathname.new(VALUESPATH).each_child{ |filepath| rename_tmp_file(filepath) }
  end

  def rename_tmp_file(filepath)
    FileUtils.mv(filepath, filepath.sub('/tmp_', '/')) if filepath.to_s['/tmp_']
  end
  
  def deduplicate_value_files
    to_dedupe = @write_counts.select{ |xpath, count| count > 1 }.keys
    to_dedupe.each{ |xpath| deduplicate_value_file(xpath) }
  end

  def deduplicate_value_file(xpath)
    tmpfile = xpath_filename(xpath)
    finalfile = tmpfile.sub('tmp_', '')

    values = file_values(tmpfile)

    File.open(finalfile, 'a') do |target|
      values.each do |val, info|
        rowdata = [val, info[:occurrences], info[:example_files].first(3).join('^^^')]
        write_row(target, rowdata)
      end
    end

    FileUtils.rm(tmpfile)
    xpath_stats(xpath, values)
  end

  def generate_stats
    to_process = @write_counts.select{ |xpath, count| count == 1 }.keys
    to_process.each do |xpath|
      values = file_values(xpath_filename(xpath))
      xpath_stats(xpath, values)
    end
  end

  def file_values(path)
    values = {}
    
    File.readlines(path).each do |line|
      splitline = line.chomp!.split(@delim)
      val, occs, exs = splitline[0], splitline[1].to_i, splitline[2].split('^^^')
      if values.key?(val)
        target = values[val]
        target[:occurrences] += occs
        target_ef = target[:example_files]
        target_ef << exs 
        target_ef.flatten.first(3)
      else
        values[val] = {occurrences: occs, example_files: exs}
      end
    end

    values
  end

  def xpath_stats(xpath, values)
    @profile[xpath][:uniqs] = values.keys.length
  end
  
  def clean_xpaths(hash)
    hash.transform_keys!{ |key| clean_xpath(key) }
  end

  def clean_xpath(xpath)
    xp = xpath.dup
    @strip.each{ |topnode| xp.sub!(/^\/#{topnode}/, '') }
    xp = xp.sub(/^\//, '')
    return '0' if xp.empty?

    xp
  end

  def write_values_over_threshold
    xpaths_over_value_threshold.each do |xpath, valhash|
      write_values(xpath, valhash)
      clear_xpath_values(xpath)
    end
  end

  def clear_xpath_values(xpath)
    @profile[xpath][:values] = {}
  end

  def xpath_filename(xpath)
    "#{VALUESPATH}/tmp_#{xpath.gsub('/', '_')}.txt"
  end

  
  def write_row(file, rowdata)
    file.write("#{rowdata.join(@delim)}\n")
  end

  def headers
    %w[value occurrences example_files]
  end
  
  def write_values(xpath, valhash)
    File.open(xpath_filename(clean_xpath(xpath)), 'a') do |valfile|
      
      valhash[:values].each do |value, info|
        rowdata = [value, info[:occurrences], info[:example_files].join('^^^')]
        write_row(valfile, rowdata)
      end
    end
    @write_counts[xpath] += 1
  end
  
  def xpaths_over_value_threshold
    @profile.select{ |xpath, hash| hash[:values].keys.length > BATCH_WRITE_THRESHOLD }
  end
  
  def merge_file_profile(fileprofiler)
    fileprofiler.profile.keys.each{ |xpath| merge_xpath_data(fileprofiler, xpath) }
  end

  def merge_xpath_data(fileprofiler, xpath)
    unless @profile.key?(xpath)
      create_profile_xpath(xpath)
      @write_counts[xpath] = 0
    end

    update_node_occurrences(fileprofiler, xpath)
    
    fileprofiler.profile[xpath][:values].each do |valkey, valval|
      merge_xpath_value(value: valkey, xpath: xpath, file: fileprofiler.name)
    end
  end

  def update_node_occurrences(fileprofiler, xpath)
    @profile[xpath][:occurrences] += fileprofiler.profile[xpath][:occurrences]
  end
  
  def create_profile_xpath(xpath)
    @profile[xpath] = {occurrences: 0, values: {}}
  end
  
  def merge_xpath_value(value:, xpath:, file:)
    setup_xpath_value(value: value, xpath: xpath) unless value_present?(value, xpath)
    target = @profile[xpath][:values][value]
    target[:occurrences] += 1
    target[:example_files] << file unless sufficient_examples?(value, xpath)
  end

  def setup_xpath_value(value:, xpath:)
    @profile[xpath][:values][value] = {occurrences: 0, example_files: []}
  end

  def value_present?(value, xpath)
    return false unless @profile.key?(xpath)

    @profile[xpath][:values].key?(value)
  end

  def sufficient_examples?(value, xpath)
    return false unless @profile.key?(xpath)

    vals_for_xpath = @profile[xpath][:values]
    return false unless vals_for_xpath.key?(value)
    
    vals_for_xpath[value][:example_files].length == 3
  end
  
  def xpath_values(valhash)
    arr = []
    valhash.each{ |val, files| arr << {occ: files.length, val: val, ex: files.first(3).join(', ')} }
    arr
  end

  def label(uniqs, occs)
    return '     ' if occs == 1 && uniqs == 1
    return 'CONST' if occs > 1 && uniqs == 1
    return 'ID   ' if uniqs == occs 
    '     '
  end
  
  def get_doc(path)
    begin
      doc = Nokogiri::XML(File.read(path)) do |config|
        config.noblanks
      end
    rescue Nokogiri::XML::SyntaxError => err
      LOG.error("Not profiled due to XML parsing error: #{f}: #{err.message}")
      @err_count += 1
      return nil
    end
    doc.remove_namespaces!
  end

  def get_files
    Dir.new(@dir).children
      .select{ |f| f.end_with?('.xml')}
      .map{ |f| "#{@dir}/#{f}" }
  end

  def xpaths
    profile.keys.sort
  end
end

class FileProfiler
  attr_reader :name
  def initialize(xml:, path:)
    @doc = xml
    @name = path.split('/').last.sub('.xml', '').to_sym
  end

  def profile
    @profile ||= populate_profile
  end

  private
  
  def populate_profile
    @profile = init_profile
    @profile.each do |path, h|
      if h.keys.any?(:type) && h[:type] == :attribute
        populate_attribute(path)
      else
        populate_text(path)
      end
    end
  end

  def populate_attribute(path)
    @doc.xpath(path).each do |node|
      base = @profile[path]
      base[:values][node.value] = nil
      base[:occurrences] += 1
    end
  end

  def populate_text(path)
    @doc.xpath(path).each do |node|
      base = @profile[path]
      base[:values][node.text.gsub("\t", ' ').gsub("\n", ' ')] = nil
      base[:occurrences] += 1
    end
  end
  
  def init_profile
    h = xpaths.map{ |p| [p, { occurrences: 0, values: {} }] }.to_h
    h.keys.select{ |k| k['/@'] }.each do |path|
      target = h[path]
      target[:type] = :attribute
      target[:name] = path.sub(/^.*\/@/, '')
    end
    h
  end

  def dirty_xpaths
    xp = {}
    @doc.traverse do |node|
      path = node.path.gsub(/\[\d+\]/, '') #remove index indicators
      xp[path] = nil
    end

    xp.keys
  end

  def xpaths
    xp = dirty_xpaths.select{ |k| k.end_with?('/text()') }
      .map{ |k| k.sub('/text()', '') }
      .reject{ |k| k == '/mods' }
      .sort

    xpaths_having_attributes.each do |path, attrs|
      attrs.each{ |a| xp << "#{path}/@#{a}" }
    end

    xp
  end

  def xpaths_having_attributes
    xp = {}
    @doc.traverse{ |node| xp[node.path.gsub(/\[\d+\]/, '')] = [] unless node.keys.empty? }
    xp.delete(@doc.root.path)
    xp.keys.each do |xpath|
      xp[xpath] = attrs_on(xpath)
    end
    xp
  end

  def attrs_on(path)
    arr = []
    @doc.xpath(path).each{ |node| arr << node.attributes.keys }
    arr.flatten.uniq
  end
end

beginning = Time.now
pm = ProfilingManager.new(dir: options[:input], strip: options[:strip], delim: options[:delim])
pm.process
pm.report_summary
puts ''
puts "Run time: #{Time.now - beginning} seconds"
