# encoding: utf-8

# License: refer to LICENSE file

# book class
module Kamishibai
	module CBZFilename
		def self.author(s)
			parse(s)[0]
		end

		def self.title(s)
			parse(s)[1]
		end

		def self.parse(s)
			s = File.basename(s)
			s.gsub!(/_/,' ')
			s.gsub!(/　/u,' ')
			s.gsub!(/\(.+?\)/,'')
			author = s.scan(/\[(.+?)\]/)[0][0] if s.scan(/\[(.+?)\]/)[0] and s.scan(/\[(.+?)\]/)[0][0]
			s.gsub!(/\[.+?\]/,'')
			#s.gsub!(/ \S\d+.*/,'')
			s.gsub!(/ \d{4}\S[\d\.]+.+/,'')
			s.gsub!(/ (v|c|第)[\d\.]+.*/iu,'')
			s.gsub!(/ vol.{0,2}[\d\.]+.*/i,'')
			s.gsub!(/ (上|中|下)\.cbz/iu,'.cbz')
			s.gsub!(/ \#[\d\.]+.*/i,'')
			s.gsub!(/ ch.{0,2}[\d\.]+.*/i,'')
			s.gsub!(/ +/,' ')
			s.gsub!(/^ /,'')
			s.gsub!(/\.cbz$/,'')
			s.gsub!(/ $/,'')
			s.gsub!(/ [\d\.]+$/,'')
			title = s

			[author, title]
		end

		private_class_method :parse
	end
		
	class Book
		attr_reader :bookcode, :title, :author, :fullpath, :mtime, :itime, :rtime, :size, :inode, :page, :pages, :fullpath_valid
		attr_writer :bookcode, :title, :author,            :mtime, :itime, :rtime, :size, :inode, :page, :pages, :fullpath_valid

		def initialize(bookcode=nil, fullpath=nil)
			if bookcode and fullpath
				@bookcode = bookcode
				@fullpath = fullpath
				if File.exists?( fullpath )
					fs = File.stat( fullpath )
					@mtime = fs.mtime.to_i

					# mark the path as valid, aka book exists in path
					@fullpath_valid = true
				end

				# create book title
				title = File.basename( fullpath )
				title.gsub!(/_/,' ')
				title.gsub!(/　/u,' ')
				title.gsub!(/\(.+?\)/,'')
				@author = title.scan(/\[(.+?)\]/)[0][0] if title.scan(/\[(.+?)\]/)[0] and title.scan(/\[(.+?)\]/)[0][0]
				title.gsub!(/\[.+?\]/,'')
				#title.gsub!(/ \S\d+.*/,'')
				title.gsub!(/ \d{4}\S[\d\.]+.+/,'')
				title.gsub!(/ (v|c|第)[\d\.]+.*/iu,'')
				title.gsub!(/ vol.{0,2}[\d\.]+.*/i,'')
				title.gsub!(/ (上|中|下)\.cbz/iu,'.cbz')
				title.gsub!(/ \#[\d\.]+.*/i,'')
				title.gsub!(/ ch.{0,2}[\d\.]+.*/i,'')
				title.gsub!(/ +/,' ')
				title.gsub!(/^ /,'')
				title.gsub!(/\.cbz$/,'')
				title.gsub!(/ $/,'')
				title.gsub!(/ [\d\.]+$/,'')
				@title = title

				@itime = Time.now.to_i
				@pages = cbz_pages?( @fullpath )

				unless @pages
					puts "Book contain no images! #{fullpath}"
				end
			end
		end

		def fullpath=(newfullpath)
			@fullpath = newfullpath

			if File.exists?(newfullpath)
				@fullpath_valid = true
			end
		end
	end
end