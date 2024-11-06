# encoding: utf-8

# License: refer to LICENSE file

# for available_drives
require 'win32ole' if RbConfig::CONFIG['host_os'] =~ /ming/

require 'zip/filesystem'
if RUBY_PLATFORM == 'java'
	require 'image_voodoo'
else
	require 'gd2-ffij'
end

# is dir restricted directory?
def restricted_dir?( dir, excludes=[] )
	# restricted directory list
	restricted_dirs = [
		'.Trash', '.Trashes', '.fseventsd', '.Spotlight-V100', '.DocumentRevisions-V100',
		'.$EXTEND',
		'_SYNCAPP',
		'Corrupted',
		'System Volume Information', 'RECYCLER',
		'backup',
		'.sparsebundle',
		'.tmpdir', '.tmp7z',
		'.AppleDouble'
	]

	for word in restricted_dirs - excludes
	    return true if dir.include?( word )
    end
    return false
end

class String
	# escape [] and {} character for Dir.glob to use
	def escape_glob
		s = self.dup
		s.gsub(/([\[\]\{\}\*\?\\])/, '\\\\\1')
	end

	# escape glob and overwite it
	def escape_glob!
		self.replace( self.escape_glob )
	end

	# escape characters and make it html safe
	def escape_html
		s = self.dup

		for i in 32..255
			next if i == 35 # #
			next if i == 38 # &
			next if i == 59 # ;
			next if i >=  48 && i <=  57 # 0-9
			next if i >=  65 && i <=  90 # A-Z
			next if i >=  97 && i <= 122 # a-z
			next if i >= 127 && i <= 159 # not defined in html standards

			c = [i].pack('U')
			r = "\&\##{i.to_s}\;"
			s.gsub!(c, r) # replace char to html number
		end

		s
	end

	# escape characters and make it html safe and overwrite
	def escape_html!
		self.replace( self.escape_html )
	end
end

# generate random char
def GenChar(length)
	length = length.to_i
	return nil if length < 1

	s = ''
	w = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ' # 62 uniq chars

	while s.length < length
		s = s + w[rand(62)]
	end

	return s
end

# return image type
def image_type(magic)
	return :unknown if magic.length < 10
	# fix because diff encoding with same data will also throws off the == match
	magic = magic[0..9].clone.force_encoding('UTF-8')

	return :jpeg if magic[0..1] == "\xff\xd8"
	return :png  if magic[0..3] == "\x89PNG"
	return :gif  if magic[0..3] == "GIF8"
	return :gd2  if magic[0..2] == "gd2"
	return :unknown
end
# /class

# show list of drives in ms windows environment
def available_drives
	if RbConfig::CONFIG['host_os'] =~ /ming/
		drives = []

		file_system = WIN32OLE.new("Scripting.FileSystemObject")
		fs_drives = file_system.Drives
		fs_drives.each do |drive|
			next unless drive.IsReady
			drives << drive.Path
		end

		drives
	else
		['/']
	end
end

# returns total number of pages for cbz file
def cbz_pages?( zfile )
	begin
		count = 0
		Zip::File.open( zfile ) { |x|
			x.each { |zobj|
				next if zobj.ftype != :file
				file_name = File.basename(zobj.name)
				next if file_name[0] == '.'
				next unless file_name =~ /\.(jpg|jpeg|png|gif)$/i
				count += 1
			}
		}
		return count
	rescue => err
		puts "error opening cbz. #{err}"
	end
	return nil
end

class String
	# allow natural sort for filename
	def naturalized
		# HACK: to fix ArgumentError (comparison of Array with Array failed).
		# cause: result like 1<=>"b" == nil, when it should be -1/0/1 for comparison during sort.
		# solution: turn number into float then up to 15 leading zero and 5 decimal float, then into string.
		# gotcha: sort wrong when number exceed 15 digits long or decimal exceed 5 decimals.
		# note: 21 - 5 - 1(dot) = 15
		scan(/[^\d\.]+|[\d\.]+/).collect { |s| s.match(/\d+(\.\d+)?/) ? ("%.5f" % s.to_f).rjust(21, "0") : s
		}
	end
end

# cbz file accessor, give file name and page and you shall receive
def open_cbz( zfile, page = 1, options = {} )
	if !FileTest.exists?(zfile)
		puts "error: cbz file not found #{zfile}"
		return nil
	end

	objs = []
	begin
		puts "open_cbz(#{zfile}, #{page})" if $debug
		Zip::File.open( zfile ) { |x|
			x.each { |zobj|
				next if zobj.ftype != :file
				file_name = File.basename(zobj.name)
				next if file_name[0] == '.'
				next unless file_name =~ /\.(jpg|jpeg|png|gif)$/i
				objs << zobj
			}
			
			if objs.length == 0
				puts "error: no image detected. #{zfile}"
				return nil
			elsif page > objs.length or page < 1
				puts "error: no such page #{page} : #{zfile}"
				return nil
			end

			objs.sort_by! { |zobj| zobj.name.to_s.naturalized }
			
			img_name = objs[page-1].name
			img_uname = img_name.clone.force_encoding('UTF-8') # unicode version of filename, or it won't print on puts
			puts "reading image… #{page} : #{img_uname} : #{zfile}" if $debug

			img_bin = x.file.read(img_name)

			return img_bin
		}
	rescue => e
		puts "Error: Failed to open zip file.\nException: #{e.exception}\nTrace: #{e.backtrace.join("\n\t")}"
		return nil
	end
end

if defined?(ImageVoodoo)
	# resize image using Java library
	def img_resize( dat, w, h, options = {} )
		puts "resizing jimage… #{w} : #{h} : #{options[:quality]} : #{options[:format]}" if $debug

		quality = options[:quality]
		format = options[:format]
		max_file_size = options[:max_file_size]

		to_resize = false
		to_resize = true if image.length > max_file_size

		ssimg = ''
		ImageVoodoo.with_bytes(dat) { |img|
			to_resize = true if img.width > w and w > 0
			to_resize = true if img.height > h and h > 0

			if to_resize
				scaleW = w / img.width
				scaleH = h / img.height

				scale = scaleW
				scale = scaleH if scaleH < scaleW

				img.scale( scale ) do |simg|
					ssimg = simg.bytes( image_type( dat ).to_s )
				end
			else 
				ssimg = dat
			end
		}

		return ssimg
	end
else
	# resize image using GD library
	#   image will maintain aspect ratio and fit within width and height specified
	#   if width or height is 0, it will use the image original resolution
	def img_resize( dat, w, h, options = {} )
		format = options[:format]
		quality = options[:quality]
		max_file_size = options[:max_file_size]

		# fork image resize into separate process
		# this is a hack to stop memory leak in linux
		rd, wr = IO.pipe
		fork do
			rd.close
			out = ""
			begin
				img = GD2::Image.load(dat)

				# get image resolution
				res = img.size
				iw = res[0]
				ih = res[1]

				# calc new width and height
				if w <= 0 and h <= 0
					# dont change resolution
					w = iw
					h = ih
				elsif w == 0
					w = (h * img.aspect).to_i

				elsif h == 0
					h = (w / img.aspect).to_i

				else
					if iw >= ih
						w = (h * img.aspect).to_i
					else
						h = (w / img.aspect).to_i
					end
				end

				# make sure it doesn't upscale image
				if iw > w and ih > h
					tick = Time.now
					img.resize!( w, h )
					tock = ((Time.now - tick).to_f * 1000).to_i
					puts "resizing image… w,h #{res.join(',')} -> #{w},#{h} quality: #{quality}  took #{tock} ms" if $debug
				end

				# use original format if not given
				unless format
					format = image_type(dat)
				end

				case format
					when :png
						out = img.png
					when :jpeg
						if quality
							out = img.jpeg( quality.to_i )
						elsif dat.length > max_file_size
							# force quality if too big
							out = img.jpeg( quality.to_i )
						else
							out = img.jpeg
						end
					when :gif
						out = img.gif
					else
						raise 'img_resize(elsif format), unknown output format'
				end

			rescue => errmsg
				puts "error: resize failed. #{w} #{h} #{quality}\n#{errmsg}"
			end

			dat = StringIO.new(out)
			len = 1024*16 # osx/bsd pipe default max size
			while !dat.eof
				wr.write(dat.read(len).force_encoding('utf-8'))
			end
		end

		wr.close
		return rd.read
	end
end

# create image thumbnail and save to cache
def mk_thumb(f_cbz, empty_return = false)
	quality = 60 #80
	width = 220 #320
	height = 0
	page = 1

	f = $settings.cache_path + '/' + File.basename( f_cbz.delete('ÿ') ).gsub('.cbz','.jpeg') # utf8-mac puts ÿ in filename, need to remove first for cross os support

	if File.exists?( f )
		if File.size( f ) == 0
			File.delete( f )
		else
			if empty_return
				# no need to return data if this is called from auto thumbnail worker
				return
			else
				# return file if it exists
				puts "thumbnail found. #{f}" if $debug
				return File.binread( f )
			end
		end
	end

	puts "thumbnail generated. #{f_cbz}" if $debug
	image = open_cbz( f_cbz, page )
	image = img_resize(image, width, height, { :quality => quality, :format => :jpeg })

	begin
		# store image to cache dir
		FileUtils.mkdir_p( File.dirname( f ) ) if ! Dir.exists?( File.dirname( f ) )
		File.binwrite( f, image )
	rescue => errmsg
		puts "\nthumbnail storage failed: #{f} >> #{errmsg} … retrying\n"
		retry
	end

	return image
end