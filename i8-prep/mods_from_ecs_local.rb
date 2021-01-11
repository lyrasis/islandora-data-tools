#!/usr/bin/env ruby
# frozen_string_literal: true

require 'fileutils'

BASEPATH = '~/code/islandora-ecs/local/datastreams'
TARGETDIR = '~/data/islandora/mods/copied'

def has_mods_dir?(streamdir)
  File.directory?("#{streamdir}/MODS")
end

basepath = File.expand_path(BASEPATH)
targetdir = File.expand_path(TARGETDIR)

[basepath, targetdir].each do |dir|
  unless File.directory?(dir)
    puts "ERROR: Directory #{dir} does not exist"
    exit
  end
end

count = 1

Dir.children(basepath).each do |pid|
  origpath = "#{basepath}/#{pid}"
  unless has_mods_dir?(origpath)
    puts "Skipping #{pid} -- no MODS"
    next
  end

  filename = "MODS.0.#{pid}.xml"
  source = "#{origpath}/MODS/MODS.0/#{filename}"
  unless File.file?(source)
    puts "#{source} does not exist"
    next
  end

  target = "#{targetdir}/#{filename}"
  
  FileUtils.cp(source, target)

  count += 1
end

puts "Copied #{count} files."

