# standard library
require 'optparse'
require 'pathname'

# other dependencies
require 'bundler/inline'
gemfile do
  source 'https://rubygems.org'
  gem 'nokogiri', '>= 1.10.4'
  gem 'progressbar', '>= 1.10.1'
  gem 'unicode-scripts'
  gem 'pry'
end

options = {}
OptionParser.new{ |opts|
  opts.banner = 'Usage: ruby altRepGroup_analysis.rb -i {input_dir}'

  opts.on('-i', '--input INPUTDIR', 'Path to directory containing MODS files to analyze'){ |i|
    options[:input] = Pathname(File.expand_path(i))
    unless options[:input].exist? && options[:input].directory?
      puts "Not a valid input directory: #{options[:input]}"
      exit
    end
  }
  opts.on('-h', '--help', 'Prints this help'){
    puts opts
    exit
  }
}.parse!

module ClassifiableScript
  require 'unicode/scripts'

  def scripts
    ignore = %w[Common Inherited Unknown]
    raw = Unicode::Scripts.scripts(value)
    raw - ignore
  end

  def latin?
    scripts == %w[Latin]
  end
  
  def vernacular?
    nonlat = scripts - %w[Latin]
    !nonlat.empty?
  end
  
  def classify
    case
    when latin?
      :latin
    when vernacular?
      :vernacular
    end
  end
end

module Reportable
  # source: thing to iterate on
  # method: method value to report back
  # data: array of other data to report back
  def report_on(source:, method:, pre: [], post: [])
    report = []
    source.each do |e|
      val = e.send(method)
      sval = string_val(val)
      prefix = xfixes(source: e, data: pre)
      suffix = xfixes(source: e, data: post)
      report << [prefix, sval, suffix].join(' -- ')
    end
    report
  end

  def string_val(val)
    case val.class
    when Array
      val.join(', ')
    else
      val
    end
  end

  def xfixes(source:, data:)    
    data.map{ |datum| source.send(datum) }.compact.join(' -- ')
  end
end

class AltRepElement
  include ClassifiableScript

  attr_reader :index, :element, :id, :filename
  def initialize(index:, element:, id:, filename:)
    @index, @element, @id, @filename = index, element, id, filename
  end

  def script_type
    classify
  end
  
  def value
    element.text
  end
end

class AltRepGroup
  include Reportable
  attr_reader :id, :elements, :filename
  def initialize(id:, elements:, filename:)
    @id, @filename = id, filename
    @elements = []
    elements.each_with_index{ |e, i| @elements << AltRepElement.new(index: i, element: e, id: id, filename: filename) }
  end
  
  def element_name
    elements.map(&:name).uniq
  end

  def different_scripts?
    true
  end

  def has_matching_elements?
    element_name.length == 1
  end

  def is_pair?
    elements.length == 2
  end

  def matching_xpaths?
    true
  end

  def multi_element?
    elements.length > 2
  end
  
  def normal_processable?
    has_matching_elements? && is_pair? && different_scripts? && matching_xpaths?
  end

  def processable?
    return false unless has_matching_elements?
  end

  def report(method:)
    report_on(source: elements, method: method, pre: %i[filename id index], post: %i[value])
  end
  
  def report_all
    "#{id} -- sz: #{elements.length} -- el: #{element_name.join(', ')} -- xpmatch: #{matching_xpaths?}"
  end

  def single_element?
    elements.length == 1
  end
end

class AltRepGroups  
  attr_reader :all, :filename
  def initialize(groups:, filename:)
    @all = groups
    @filename = filename
  end

  def normal
    all.select(&:normal_processable?)
  end

  def unprocessable
    all.reject(&:processable?)
  end

  def single
    all.select(&:single_element?)
  end

  def multi
    all.select(&:multi_element?)
  end

  def report(method:)
    all.map{ |arg| arg.report(method: method) }.flatten
  end
end


class ModsFiles
  include Reportable
  
  attr_reader :all
  def initialize(inputdir:)
    @all = inputdir.children.map{ |path| ModsFile.new(path: path) }
  end

  def alt_rep_groups
    all.map{ |mods| mods.alt_rep_groups.all }
      .flatten
  end
  
  def elements
    all.map{ |mods| mods.alt_rep_groups.all.map{ |arg| arg.elements } }
      .flatten
  end
  
end

class ModsFile
  attr_reader :name
  def initialize(path:)
    @path = path
    @name = path.basename('.*').to_s
  end

  def alt_rep_groups
    @alt_rep_groups ||= extract_alt_rep_groups
  end

  def report(method:)
    alt_rep_groups.all.map{ |arg| arg.report(method: method) }.flatten
  end

  def xml
    @xml ||= get_xml
  end

  private

  def extract_alt_rep_groups
    nodes = xml.xpath('//*[@altRepGroup]')
    return [] if nodes.empty?

    groups = nodes.group_by{ |n| n['altRepGroup'] }
      .map{ |id, elementset| AltRepGroup.new(id: id, elements: elementset, filename: name) }

    AltRepGroups.new(groups: groups, filename: name)
  end

  def get_xml
    Nokogiri::XML(@path.read, &:noblanks)
  end
end


mods = ModsFiles.new(inputdir: options[:input])

m = mods.all.first
malg = m.alt_rep_groups

binding.pry
