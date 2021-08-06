# standard library
require 'fileutils'
require 'optparse'
require 'pathname'

# other dependencies
require 'bundler/inline'
gemfile do
  source 'https://rubygems.org'
  gem 'diffy'
  gem 'nokogiri', '>= 1.10.4'
  gem 'progressbar', '>= 1.10.1'
  gem 'unicode-scripts'
  gem 'pry'
  gem 'byebug'
  gem 'pry-byebug'
end

options = {}
OptionParser.new{ |opts|
  opts.banner = 'Usage: ruby altRepGroup_analysis.rb -i {input_dir} -o {output_dir}'

  opts.on('-i', '--input INPUTDIR', 'Path to directory containing MODS files to analyze'){ |i|
    options[:input] = Pathname(File.expand_path(i))
    unless options[:input].exist? && options[:input].directory?
      puts "Not a valid input directory: #{options[:input]}"
      exit
    end
  }
  opts.on('-o', '--output OUTPUTDIR', 'Path to directory in which to save edited MODS'){ |o|
    options[:output] = Pathname(File.expand_path(o))
    unless options[:output].exist? && options[:output].directory?
      FileUtils.mkdir_p(options[:output])
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

  attr_reader :index, :element, :id, :filename, :path
  def initialize(index:, element:, id:, filename:)
    @index, @element, @id, @filename = index, element, id, filename
    @path = element.path
  end

  def describe
    "#{filename} -- #{id} -- #{index} -- #{name}"
  end
  
  def empty?
    element.text.empty?
  end

  def name
    element.name
  end
  
  def script_type
    classify
  end

  def signature
    @signature ||= get_signature
  end

  def get_signature
    leaves.map{ |leaf| leaf_print(leaf) }.sort
  end

  def leaves
    element.xpath('.//*[not(*)]').to_a
  end

  def leaf_print(leaf)
    sig = leaf_signature(leaf)
    rev = ancestors(leaf).reverse
    rev << sig
    rev.join('/')
  end

  def ancestors(leaf)
    ignore = %w[document mods]
    leaf.ancestors
      .reject{ |lf| ignore.any?(lf.name) }
      .map{ |anc| leaf_signature(anc) }
  end
  
  def leaf_signature(leaf)
    ignore = %w[altRepGroup lang script transliteration]
    sig = []
    return leaf.name if leaf.attributes.empty?

    sig << leaf.name
    leaf.attributes.values.each do |attr|
      next if ignore.any?(attr.name)

      sig << "@#{attr.name}='#{attr.value}'"
    end
    sig.join(' ')
  end
  
  def to_s
    element.to_s
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

  def duplicate_elements?
    elements.map(&:to_s).uniq.length == 1 && elements.length > 1
  end
  
  def describe
    "#{filename} -- #{id} -- #{element_name.join(', ')}"
  end

  def element_name
    elements.map(&:name).uniq
  end

  def has_matching_elements?
    element_name.length == 1
  end

  def is_pair?
    elements.length == 2
  end

  def latin_element
    elements.select{ |element| element.script_type == :latin }.first
  end

  def matching_xpaths?
    elements.map(&:signature).uniq.length == 1
  end

  def multi_element?
    elements.length > 2
  end
  
  def processable?
    has_matching_elements? && is_pair? && matching_xpaths? && processable_scripts?    
  end

  def processable_scripts?
    script_types == %i[latin vernacular]
  end

  def report(method:)
    report_on(source: elements, method: method, pre: %i[filename id index], post: %i[value])
  end
  
  def script_types
    elements.map(&:script_type).sort
  end

  def single_element?
    elements.length == 1
  end

  def unique_elements?
    elements.map(&:to_s).uniq.length == elements.length
  end

  def vernacular_element
    elements.select{ |element| element.script_type == :vernacular }.first
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

  def first_title
    xml.remove_namespaces!
      .xpath('/mods/titleInfo[not(@type)]/title')
      .first
      .text
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
    return AltRepGroups.new(groups: [], filename: name) if nodes.empty?

    groups = nodes.group_by{ |n| n['altRepGroup'] }
      .map{ |id, elementset| AltRepGroup.new(id: id, elements: elementset, filename: name) }

    AltRepGroups.new(groups: groups, filename: name)
  end

  def get_xml
    Nokogiri::XML(@path.read, &:noblanks)
  end
end

class Reporter
  attr_reader :mods
  def initialize(mods:)
    @mods = ModsFiles.new(inputdir: mods)
  end

  def duplicate_elements
    mods.alt_rep_groups.select(&:duplicate_elements?)
  end
  
  def empty_elements
    mods.elements.select{ |e| e.empty? }
  end

  def matching_xpath_groups
    mods.alt_rep_groups.select(&:matching_xpaths?)
  end

  def multi_element_groups
    mods.alt_rep_groups.select(&:multi_element?)
  end
  
  def non_matching_element_groups
    mods.alt_rep_groups.reject(&:has_matching_elements?)
  end

  def non_matching_xpath_groups
    groups = mods.alt_rep_groups.reject(&:matching_xpaths?).select(&:has_matching_elements?)

    groups.each do |group|
      puts "\n\n----------------------------------------"
      puts "#{group.filename}, group #{group.id}"
      puts "----------------------------------------"

      puts group.elements.join("\n---\n")
    end
  end

  def processable
    mods.alt_rep_groups.select(&:processable?)
  end

  def single_element_groups
    mods.alt_rep_groups.select(&:single_element?)
  end

  def unprocessable_script_groups
    mods.alt_rep_groups.reject(&:processable_scripts?)
  end
end

class XmlEditor
  attr_reader :dir, :data, :opts
  def initialize(dir:, data:, report: false, **opts)
    @dir = dir
    @data = data
    @report = report
    @opts = opts
  end

  def process
    data.each do |filename, datum|
      doc = read_xml(filename)
      rev_doc = make_edits(datum, doc)
      report(filename) if @report
      write_xml(filename, rev_doc)
    end
  end

  private
  
  def read_xml(filename)
    Nokogiri::XML(Pathname.new("#{dir}/#{filename}.xml").read, &:noblanks)
  end

  def remove_attributes(element, attributes)
    attributes.each do |attr|
      element.remove_attribute(attr) if element.keys.any?(attr)
    end
    element
  end

  def report(filename)
    puts "#{message}#{filename}.xml"
  end
  
  def write_xml(filename, doc)
    File.open("#{dir}/#{filename}.xml", 'w'){ |file| doc.write_xml_to(file) }
  end
end

class ElementDeleter < XmlEditor
  def make_edits(elements, doc)
    elements.map(&:path).reverse.each do |path|
      doc.xpath(path).first.remove
    end    
    doc
  end

  def message
    'Deleted element(s) from '
  end
end

class AltRepGroupFixer < XmlEditor
  class UnprocessableGroupError < StandardError; end
  
  def make_edits(groups, doc)
    groups.each do |group|
      raise UnprocessableGroupError, "#{group.filename} altRepGroup #{group.id}" unless group.processable?

      attrs = %w[altRepGroup lang script transliteration]
      vernacular = remove_attributes(group.vernacular_element.element, attrs).to_s
      doc.xpath(group.latin_element.path).first.replace(vernacular)
    end
    delete_old_vernacular(groups, doc)
    doc
  end

  private

  def delete_old_vernacular(groups, doc)
    paths = groups.map{ |grp| grp.vernacular_element.path }
    rpaths = paths.reverse
    nodes = rpaths.map{ |path| doc.xpath(path).first }

    nodes.each do |node|
      node.remove
    end
    doc
  end

  def message
    "Fixed altRepGroup(s) in "
  end
end

class AttributeRemover < XmlEditor
  attr_reader :attributes
  def initialize(dir:, data:, report: false, attributes:)
    super
    @attributes = attributes
  end
  
  def make_edits(groups, doc)
    to_elements(groups).each do |element|
      cleaned = remove_attributes(element.element, attributes).to_s
      doc.xpath(element.path).first.replace(cleaned)
    end
    doc
  end

  private

  def get_elements(group)
    return group if group.is_a?(AltRepElement)
    group.elements
  end
  
  def message
    "Deleted attributes #{@attributes.join(', ')} from "
  end

  def to_elements(groups)
    groups.map{ |grp| get_elements(grp) }.flatten
  end
end

class DeduplicateElements < XmlEditor
  def make_edits(groups, doc)
    groups.each do |group|
      to_delete = doc.xpath("//*[@altRepGroup='#{group.id}']")
      to_delete.shift
      next if to_delete.empty?
      
      to_delete.each{ |node| node.remove }
    end
    doc
  end

  def message
    'Deduplicated elements in '
  end
end

class Diff
  require 'diffy'
  
  def initialize(orig:, processed:)
    @orig = orig
    @processed = processed
    @files = ModsFiles.new(inputdir: @orig).all.map(&:name).map{ |name| "#{name}.xml" }
    @report_path = Pathname.new("#{processed}/_diff.txt")
    @unchanged = []
    @changed = []
  end

  def report
    puts "#{@files.length} total files"
    compile_results
    puts "#{@unchanged.length} unchanged files"
    puts "#{@changed.length} changed files"
    write_summary
    write_full
  end

  private

  def compile_results
    @files.each do |file|
      result = diff_result(file)
      status = result.status
      @unchanged << file if status == :unchanged
      next if status == :unchanged 

      @changed << result
    end
  end
  
  def diff_result(file)
    result = Diffy::Diff.new("#{@orig}/#{file}", "#{@processed}/#{file}", source: 'files',
                             context: 0)
    DiffResult.new(file, result.to_s)
  end

  def div
    "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=\n"
  end
  
  def header(file)
    "#{div}#{file}\n#{div}"
  end

  def footer(file)
    "\n\n"
  end

  def write_full
    File.open(@report_path, 'a') do |reportfile |
      @changed.each do |result|
        file = result.file
        reportfile.write(header(file))
        reportfile.write(result.content)
        reportfile.write(footer(file))
      end
    end
  end

  def write_summary
    File.open(@report_path, 'w') do |reportfile |
      reportfile.write("#{@changed.length} changed files -- #{@unchanged.length} unchanged files\n")
      reportfile.write("\n#{div}List of unchanged files\n#{div}")
      reportfile.write(@unchanged.join(', '))
      reportfile.write("\n")
    end
  end
end

Result = Struct.new(:file, :content, :status)

class TitleDiff < Diff
  def report
    set_report_path
    super
  end

  private
  
  def diff_result(file)
    files = [File.join(@orig, file), File.join(@processed, file)]
    titles = files.map{ |file| first_title(file) }.uniq
    return Result.new(file, '', :unchanged) if titles.length == 1

    content = "#{file.delete_suffix('.xml')}\t#{titles[1]}\n"
    Result.new(file, content, :changed)
  end
  
  def first_title(file)
    doc = ModsFile.new(path: Pathname.new(file))
    doc.first_title
  end

  def set_report_path
    @report_path = @report_path.dirname.join('title_changes.txt')
  end

  def write_full
    File.open(@report_path, 'w') do |reportfile|
      @changed.each do |result|
        reportfile.write(result.content)
      end
    end
  end
end


class DiffResult
  attr_reader :file, :content, :status
  def initialize(file, result)
    @file = file
    @content = result
    @status = result.empty? ? :unchanged : :changed
  end
end

# copy all processable files to the output folder so we can just read/write from there
# options[:input].children.each do |c|
#   #  next if File.exist?("#{options[:output].to_s}/#{c.basename}")

#   FileUtils.cp(c, options[:output])
# end

# # Delete empty altRepGroup elements
# reporter = Reporter.new(mods: options[:output])
# empty = reporter.empty_elements.group_by(&:filename)
# ed = ElementDeleter.new(dir: options[:output], data: empty)
# ed.process

# # Remove duplicate elements within altRepGroup
# reporter = Reporter.new(mods: options[:output])
# duplicates = reporter.duplicate_elements.group_by(&:filename)
# de = DeduplicateElements.new(dir: options[:output], data: duplicates)
# de.process

# # Remove attributes from single-element altRep"Group"s
# reporter = Reporter.new(mods: options[:output])
# singles = reporter.single_element_groups.group_by(&:filename)
# ar = AttributeRemover.new(dir: options[:output],
#                           data: singles,
#                           attributes: %w[altRepGroup lang script transliteration])
# ar.process

# reporter = Reporter.new(mods: options[:output])
# processable = reporter.processable.group_by(&:filename)
# fixer = AltRepGroupFixer.new(dir: options[:output], data: processable, report: true)
# fixer.process

# d = Diff.new(orig: options[:input], processed: options[:output])
# d.report

td = TitleDiff.new(orig: options[:input], processed: options[:output])
td.report
# # For reporting things that will be ignored
# reporter = Reporter.new(mods: options[:output])
# nme = reporter.non_matching_element_groups
# me = reporter.multi_element_groups
# us = reporter.unprocessable_script_groups
# mx = reporter.matching_xpath_groups
# nmx = reporter.non_matching_xpath_groups

