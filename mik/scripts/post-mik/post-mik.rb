# standard library
require 'fileutils'
require 'logger'
require 'pp'
require 'yaml'

# gems
require 'nokogiri'
require 'progressbar'
require 'slop'

opts = Slop.parse do |o|
  o.string '-t', '--targetdir', 'path to target directory for processing'
  o.bool '-b', '--backup', 'back up your mods files before processing'
  o.bool '-r', '--restore', 'put backed up files in their original locations'
  o.bool '-v', '--verbose', 'make the screen scroll...'
  o.bool '--transform', 'run the xsl transformations listed in the config file'
  o.bool '--validate', 'validate against MODS schema specified in config file'
  o.on '--help' do
    puts o
    exit
  end
end


# ruby post-mik output_directory_path
config = YAML.load_file('config.yaml')

wrk_dir = File.expand_path(opts[:targetdir])

if Dir::exists?(wrk_dir)
  Dir.chdir(wrk_dir)
  parent_dir = File.expand_path('..')
  dir_name = wrk_dir.sub(parent_dir, '')
else
  puts "ERROR: #{wrk_dir} is not a valid directory."
  exit
end

backup_dir = "#{parent_dir}/#{dir_name}-mods_backup"

def backup_mods(modspath, backupdir, wrkdir, opts)
  backupname = modspath.sub(wrkdir, '').sub(/^\//,'').gsub('/','-')
  if opts[:verbose]
    FileUtils.cp(modspath, "#{backupdir}/#{backupname}", :verbose => true)
  else
    FileUtils.cp(modspath, "#{backupdir}/#{backupname}")
  end
end

def transform_mods(mods, out, xsl, saxon, log, opts)
  transform = `java -jar #{saxon} -t -s:#{mods} -xsl:#{xsl} -o:#{out} 2>&1`
  if $?.success?
    message = "Successfully applied #{xsl} to #{mods}" 
    log.info(message)
  else
    message = "Application of #{xsl} to #{mods} failed: #{transform}"
    log.error(message)
  end
  puts message if opts.verbose?
end

def replace_files(output_dir, opts)
  outdir = File.absolute_path(output_dir)
  todir = File.absolute_path(opts[:targetdir])
  files = Dir.glob("#{outdir}/*.xml").map{ |f| { :srcpath => f,
                                                 :endpath => File.basename(f).split('-').join('/') }
  }
  files.each do |f|
    f[:targetpath] = "#{todir}/#{f[:endpath]}".sub('//', '/')
    puts "Moving #{f[:srcpath]} to #{f[:targetpath]}" if opts.verbose?
    FileUtils.mv(f[:srcpath], f[:targetpath])
  end
end

xsl_list = config['stylesheets'].map{ |path| File.expand_path(path) }
saxon_path = File.expand_path(config['saxon_path'])
mods_schema = File.expand_path(config['mods_schema'])

puts "\nCompiling list of MODS files..."

mods_paths = Dir.glob('**/*.xml').map{ |x| File.absolute_path(x) }
mods_paths.reject!{ |path| path.include?('structure.xml') }

if mods_paths.length == 0
  puts 'No MODS in directory. Exiting...'
  exit
else
  mods_ct = mods_paths.length
end

if opts.backup?
  puts "Backing up MODS to: #{backup_dir}"
  if Dir::exists?(backup_dir)
    puts "Directory #{backup_dir} already exists. Exiting to avoid overwriting your actual original MODS..."
    exit
  else
    Dir.mkdir(backup_dir)
  end
  mods_paths.each { |m| backup_mods(m, backup_dir, wrk_dir, opts) }
end

if opts.restore?
  replace_files(backup_dir, opts)
end

if opts.transform?
  xsl_log = Logger.new("#{parent_dir}/xsl_processing.log")

  xsl_list.each do |xsl|
    puts "\n\nRunning XSLT transformation: #{xsl}"

    tmp_input_dir = "#{parent_dir}/tmp_in"
    tmp_output_dir = "#{parent_dir}/tmp_out"
    Dir.mkdir(tmp_input_dir) unless Dir::exists?(tmp_input_dir)
    Dir.mkdir(tmp_output_dir) unless Dir::exists?(tmp_output_dir)
    mods_paths.each { |m| backup_mods(m, tmp_input_dir, wrk_dir, opts) }

    transform_mods(tmp_input_dir, tmp_output_dir, xsl, saxon_path, xsl_log, opts)

    replace_files(tmp_output_dir, opts)
    FileUtils.remove_dir(tmp_input_dir, force = true)
    FileUtils.remove_dir(tmp_output_dir, force = true)
  end

  xsl_log.info("End of batch processing\n\n\n")
  xsl_log.close
end

if opts.validate?
  v_log = Logger.new("#{parent_dir}/validation.log")

  schema = Nokogiri::XML::Schema(File.read(mods_schema))

  puts "\n\nValidating MODS against #{schema}..."
  progressbar = ProgressBar.create(:format => '%a |%b>>%i| %p%% %t', :autofinish => false)
  ct = 0
  factor = 100.to_f / mods_ct.to_f
  fct = 0
  mods_paths.each do |mods|
    doc = Nokogiri::XML(File.read(mods))
    v = schema.validate(doc)
    if v.length == 0
      v_log.info "Valid MODS: #{mods}"
    else
      v_log.error "Invalid MODS: #{mods}"
      v.each { |e| v_log.error e }
    end
    ct += 1
    new_fct = (ct * factor).floor
    unless new_fct == fct
      progressbar.increment
      fct = new_fct
    end
  end
end

puts "\nDone!"
