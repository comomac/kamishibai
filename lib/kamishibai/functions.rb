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
	magic = magic[0..9]
	case magic
		when /^\xff\xd8/n
			:jpeg
		when /^\x89PNG/n
			:png
		when /^GIF8/n
			:gif
		when /^\x00/n
			:wbmp
		when /^gd2/n
			:gd2
		else
			:unknown
	end
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
	i = 0
	begin
		Zip::File.open( zfile ) { |x|
			x.each { |zobj|
				if zobj.ftype == :file and File.basename(zobj.name)[0] != '.' and File.basename( zobj.name ) =~ /\.(jpg|jpeg|png|gif)$/i
					i += 1
				end
			}
		}
	rescue
		return nil
	end
	return i
end


# cbz file accessor, give file name and page and you shall receive
def open_cbz( zfile, page = 1, options = {} )
	objs = []
	# begin
		Zip::File.open( zfile ) { |x|
			x.each { |zobj|
				if zobj.ftype == :file and File.basename(zobj.name)[0] != '.' and File.basename( zobj.name ) =~ /\.(jpg|jpeg|png|gif)$/i
					objs << zobj
				end
			}
			objs.sort!

			if objs.length == 0
				puts "error: no image detected. #{zfile}"
				return nil
			elsif page > objs.length or page < 1
				puts "error: no such page #{page} : #{zfile}"
				return nil
			else
				img = objs[page-1].name
				uimg = img.clone.force_encoding('UTF-8') # unicode version of filename, or it won't print on puts
				puts "reading image… #{page} : #{uimg} : #{zfile}" if $debug

				simg = x.file.read(img)

				begin
					# load the image to check if the image is corrupted or not
					GD2::Image.load( simg ) if defined?(GD2)
				rescue => errmsg
					puts "error: fail to load image #{page} : #{zfile}"
					p errmsg
					return nil
				end

				return simg
			end
		}
	# rescue => e
	# 	puts "Corrupted zip file."
	# 	puts e.exception
	# 	puts e.backtrace
	# end
end

if defined?(ImageVoodoo)
	# resize image using Java library
	def img_resize( dat, w, h, options = {} )
		puts "resizing jimage… #{w} : #{h} : #{options[:quality]} : #{options[:format]}" if $debug

		quality = options[:quality]
		format = options[:format]

		ssimg = ''
		ImageVoodoo.with_bytes(dat) { |img|
			scale = 1280 / img.width

			img.scale( scale ) do |simg|
				ssimg = simg.bytes( image_type( dat ).to_s )
			end
		}

		return ssimg
	end
else
	# resize image using GD library
	#   image will maintain aspect ratio and fit within width and height specified
	#   if width or height is 0, it will use the image original resolution
	def img_resize( dat, w, h, options = {} )
		quality = options[:quality]
		format = options[:format]

		begin
			img = GD2::Image.load(dat)

			# get image resolution
			res = img.size
			iw = res[0]
			ih = res[1]

			# calc new width and height
			if w == 0
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

			puts "resizing image… width: #{w}, height: #{h}, quality: #{quality}" if $debug

			# make sure it doesn't upscale image
			if iw > w and ih > h
				img.resize!( w, h )
			end

			if format
				case format
					when :png
						img.png
					when :jpeg
						if quality
							img.jpeg( quality.to_i )
						else
							img.jpeg
						end
					when :gif
						img.gif
					else
						raise 'img_resize(elsif format), unknown output format'
				end
			else
				case image_type(dat)
					when :png
						img.png
					when :jpeg
						if quality
							img.jpeg( quality.to_i )
						else
							img.jpeg
						end
					when :gif
						img.gif
					else
						raise 'img_resize(else), unknown output format'
				end
			end

		rescue => errmsg
			puts "error: resize failed. #{w} #{h} #{quality}"
			p errmsg
			return nil
		end
	end
end

# create image thumbnail and save to cache
def mk_thumb(f_cbz, auto_gen = false)
	unless auto_gen
		# holds the last time the open_cbz is called
		# to pause the Thumbnail Generator thread
		$open_cbz_ltime = Time.now
	end

	quality = 60 #80
	width = 220 #320
	height = 0
	page = 1

	f = $settings.cache_path + '/' + File.basename( f_cbz.delete('ÿ') ).gsub('.cbz','.jpeg') # utf8-mac puts ÿ in filename, need to remove first for cross os support

	if File.exists?( f )
		if File.size( f ) == 0
			File.delete( f )
		else
			if auto_gen
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