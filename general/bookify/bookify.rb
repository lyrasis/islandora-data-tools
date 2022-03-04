# bookify.rb wrk_path img_format

require 'zip'

params = ARGV
wdir = params[0]
iformat = params[1]

Dir.chdir(wdir)
bk_ids = Dir.glob('*.xml').map { |n| n.sub('.xml','') }

bk_ids.each do |id|
  Dir.mkdir(id) unless Dir::exists?(id)
  images = Dir.glob("#{id}_*.#{iformat}")

  images.each do |image|
    image_number = image.sub("#{id}_",'').sub(".#{iformat}",'')
    page_path = "#{id}/#{image_number}"
    Dir.mkdir(page_path) unless Dir::exists?(page_path)
    File.rename(image, "#{page_path}/OBJ.#{iformat}") if File::exists?(image)
  end

  mods_file = "#{id}.xml"
  File.rename(mods_file, "#{id}/MODS.xml") if File::exists?(mods_file)
end

zipfile_name = "#{wdir}/books.zip"

Zip::File.open(zipfile_name, Zip::File::CREATE) do |zipfile|
      Dir.glob("**/*").reject {|fn| File.directory?(fn) }.each do |file|
        puts "Adding #{file}"
        zipfile.add(file.sub(wdir + '/', ''), file) unless file.include?('.pdf') || file.include?('.zip')
      end
end


