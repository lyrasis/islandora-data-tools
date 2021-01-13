require 'bundler/inline'
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

require 'facets/array/before'
require 'facets/hash/deep_merge'

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
  opts.on('-h', '--help', 'Prints this help'){
    puts opts
    exit
  }
}.parse!

PROFILEPATH = "#{options[:input]}/profile"
Dir::mkdir(PROFILEPATH) unless Dir::exist?(PROFILEPATH)
logpath = "#{PROFILEPATH}/profile_log.txt"
LOG = Logger.new(logpath)

class ProfilingManager
  attr_reader :file_count, :err_count, :profile
  def initialize(dir:)
    @dir = dir
    @files = get_files
    @file_count = @files.length
    @err_count = 0
    @profile = {}
  end

  def process
    puts "Profiling #{file_count} files\n\n"
    progress = ProgressBar.create(:starting_at => 0,
                                  :total => file_count,
                                  :format => '%a |%b>>%i| %p%% %t')
    puts ''

    @root = get_doc(@files.first).root.path
    
    @files.each do |file|
      doc = get_doc(file)
      fp = FileProfiler.new(xml: doc, path: file)
      @profile = profile.deep_merge(fp.profile)
      progress.increment
    end
    progress.finish
    profile.transform_keys!{ |k| k.sub("#{@root}/", '') }
  end

  def report_elements_and_attributes_used
    puts xpaths
  end

  def report_summary
    occlabel = 'OCCURRENCES'
    uniqlabel = 'UNIQUES'
    puts "      \t#{occlabel}\t#{uniqlabel}\tXPATH"
    xpaths.each do |xpath|
      data = profile[xpath]
      occ = occurrences(data).to_s.rjust(occlabel.length, ' ')
      uniq = uniques(data).to_s.rjust(uniqlabel.length, ' ')
      puts "#{label(data)}\t#{occ}\t#{uniq}\t#{xpath}"
    end
  end

  # def report_limited_values(int)
  #   occlabel = 'OCCURRENCES'
  #   uniqlabel = 'UNIQUES'
  #   puts "      \t#{occlabel}\t#{uniqlabel}\tXPATH"
  #   xpaths.each do |xpath|
  #     data = profile[xpath]
  #     occ = occurrences(data).to_s.rjust(occlabel.length, ' ')
  #     uniq = uniques(data).to_s.rjust(uniqlabel.length, ' ')
  #     dispvals = get_disp_vals(data[:values], int)
  #     puts "#{label(data)}\t#{occ}\t#{uniq}\t#{xpath}"
  #   end
  # end

  private

  # def get_disp_vals(valhash, int)
  #   disp_vals = []
    
  # end

  def label(path_data)
    vals = path_data[:values]
    occs = occurrences(path_data)
    
    if vals.length == 1 && occs > 1
      'CONST'
    elsif occs > 1 && uniques(path_data) == occs 
      'ID   '
    else
      '     '
    end
  end

  def uniques(path_data)
    path_data[:values].keys.length
  end

  def occurrences(path_data)
    path_data[:values].values.flatten.length
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
  attr_reader :profile
  def initialize(xml:, path:)
    @doc = xml
    @name = path.split('/').last.sub('.xml', '').to_sym
    @profile = init_profile
    populate_profile
    @doc = nil
  end

  def populate_profile
    profile.each do |path, h|
      if h.keys.any?(:type) && h[:type] == :attribute
        populate_attribute(path)
      else
        populate_text(path)
      end
    end
  end

  def populate_attribute(path)
    @doc.xpath(path).each do |node|
      base = profile[path][:values]
      value = node.value
      base.key?(value) ? base[value] << @name : base[value] = [@name]
    end
  end

  def populate_text(path)
    @doc.xpath(path).each do |node|
      base = profile[path][:values]
      value = [node.text]
      base.key?(value) ? base[value] << @name : base[value] = [@name]
    end
  end
  
  def init_profile
    h = xpaths.map{ |p| [p, { :values => {} }] }.to_h
    h.keys.select{ |k| k['/@'] }.each do |path|
      h[path][:type] = :attribute
      h[path][:name] = path.sub(/^.*\/@/, '')
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

  def attr
    xa = xpaths_having_attributes
  end
end

pm = ProfilingManager.new(dir: options[:input])
pm.process
#pm.report_elements_and_attributes_used

pm.report_summary
