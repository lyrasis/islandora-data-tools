require 'csv'
require 'optparse'
require 'pp'

require 'bundler/inline'
gemfile do
  source 'https://rubygems.org'
  gem 'pry', '>= 0.13.0'
end

=begin
Reports the longest character count in a given column or set of columns.

Takes a multivalue delimiter. If given, will split the column using that delimiter and
will base analysis on split values.

`id` is column name used to report up to three examples of rows having the longest value.
=end

options = {}
OptionParser.new{ |opts|
  opts.banner = 'Usage: ruby longest_occurrence.rb -i ~/data/my.csv -c column1,column5 -d ;;;'

  opts.on('-i', '--input STRING', 'Path to CSV'){ |i|
    options[:input] = File.expand_path(i)
  }
  opts.on('-c', '--column STRING', 'Comma delimited names of columns to analyze'){ |c|
    options[:column] = c.split(',')
  }
  opts.on('-d', '--delimiter STRING', 'Delimiter for splitting multivalue columns'){ |d|
    options[:delimiter] = d
  }
  opts.on('--id STRING', 'Name of column to report'){ |i|
    options[:id] = i
  }

}.parse!
  
class Column
  def initialize(path, colname, idcol, delim)
    @colname = colname
    @idcol = idcol
    @delim = delim
    
    @maxlength = 0
    @examples = []

    CSV.foreach(path, headers: true){ |row| process_row(row) }
  end

  def to_s
    "#{@colname}: max length: #{@maxlength} #{@examples.join(', ')}"
  end

  private

  def column_values(column_value)
    @delim.nil? ? [column_value] : column_value.split(@delim)
  end

  def process_row(row)
    val = row[@colname]
    return if val.nil?
    
    vals = column_values(val).map{ |value| ColumnValue.new(row[@idcol], value)}
    vals.each{ |val| process_value(val) }
  end

  def process_value(val)
    return if val.length < @maxlength
    return if val.length == @maxlength && @examples.length == 3

    @examples << val.id if val.length == @maxlength
    return if val.length == @maxlength

    @maxlength = val.length
    @examples = [val.id]
  end
end

class ColumnValue
  attr_reader :id, :value, :length
  def initialize(id, value)
    @id, @value = id, value
    @length = @value.length
  end
end

options[:column].each do |colname|
  c = Column.new(options[:input], colname, options[:id], options[:delimiter])
  puts c
end

