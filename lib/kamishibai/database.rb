# encoding: utf-8

# License: refer to LICENSE file

#
# Functions for database and bookmarks
#

require 'json'
require 'fileutils'
require 'pathname'

module Kamishibai
	class Database
		attr_reader :files, :bookcodes

		def initialize( db_filepath, bookmarks_filepath )
			@db_savepath = db_filepath
			@db_dirty = true

			if File.exists?( @db_savepath )
				load_database
			else
				# create fresh database
				@db = {}
				# indexes
				@bookcodes = []
				@files = {}
				@inodes = {}
			end


			# bookmark section
			@bookmarks_savepath = bookmarks_filepath
			@bookmarks_dirty = false

			if File.exists?( @bookmarks_savepath )
				load_bookmarks
			end
		end

		def add_book(filepath)
			bookcode = gen_bookcode
			o = Kamishibai::Book.new(bookcode, filepath)

			if o.pages
				@db[ bookcode ] = o
				@bookcodes << bookcode
				if File.exists?( filepath )
					@files[ File.basename( filepath ).delete('ÿ') ] = bookcode # utf8-mac puts ÿ in filename, need to remove first for cross os support
					@inodes[ o.inode ] = bookcode
				end

				@db_dirty = true

				puts "added book. #{bookcode} #{filepath}" if $debug
				bookcode
			end
		end

		def has_bookcode?(bookcode)
			@bookcodes.include?( bookcode )
		end

		def get_book(bookcode)
			@db[ bookcode ]
		end

		def get_bookcode_byfilename(filename)
			filename = File.basename( filename )
			@files[ filename ]
		end

		def get_book_byfilename(filename)
			filename = File.basename( filename )
			bookcode = @files[ filename ]
			get_book( bookcode )
		end

		def set_bookmark(bookcode, page)
			puts "set_bookmark #{bookcode} #{page}" if $debug
			@bookmarks_dirty = true
			o = get_book(bookcode)
			o.page  = page
			o.rtime = Time.now.to_i
		end

		def get_bookmark(bookcode)
			get_book( bookcode ).page
		end

		def books
			@db
		end

		# refresh @bookcodes, making sure all the books have valid path
		def refresh_bookcodes
			bookcodes = []
			for bookcode, book in @db
				if File.exists?( book.fullpath )
					book.exists = true
					bookcodes << bookcode
				else
					book.exists = false
				end
			end

			@bookcodes = bookcodes
		end
		

		# big codes

		# add book from directories, if existing booka are found, modify instead
		def add_books(srcs, recursive = true)
			srcs = cleanup_srcs( srcs )
			
			for src in srcs
				# stopped using find module, because it wrack encoding havoc in windows (gives ??? character in unicode filename)
				# now using Dir.glob instead
				if recursive
					search = '/**/*.cbz'
				else
					search = '/*.cbz'
				end

				Dir.glob(File.expand_path(src).escape_glob + search).delete_if { |f|
					restricted_dir?(f)
				}.each { |f|
					bc = get_bookcode_byfilename( f )
					o  = get_book( bc )
					fs = File.stat(f)
					o2 = get_book( @inodes[ fs.ino ] )

					if o
						# book exists in db
						puts "book match(m1):     #{File.basename(f)} == #{File.basename(o.fullpath)}" if $debug == 2
						
						# update data with new path
						o.fullpath = f

						# update index, as bookcodes is the list that keeps actual books that exists
						@bookcodes << o.bookcode
					elsif o2 and fs.size == o2.size
						# found existing book using inode and size, can detected changed filename in same filesystem
						puts "book match(m2):     #{File.basename(f)} == #{File.basename(o2.fullpath)}" if $debug == 2

						o2.fullpath = f
						o2.title    = Kamishibai::CBZFilename.title( f )
						o2.author   = Kamishibai::CBZFilename.author( f )

						# update indexes
						@bookcodes << o2.bookcode
						@files[ File.basename(f) ] = o2.bookcode
					else
						# book don't exist in db
						self.add_book(f)
					end
				}
			end

			puts "Found #{@bookcodes.length} books" if $debug
		end

		# save database
		def save
			if @db_dirty
				# create dir if dir doesn't exist
				if ! FileTest.exists?( File.dirname( @db_savepath ) )
					FileUtils.mkdir_p( File.dirname( @db_savepath ) )
				end
				
				db = {}
				@db.each { |bookcode, book|
					next unless book.pages # skip invalid book that contain no page/images

					db[ bookcode ] = {
						:title    => book.title,
						:author   => book.author,
						:fullpath => book.fullpath,
						:size     => book.size,
						:inode    => book.inode,
						:mtime    => book.mtime,
						:itime    => book.itime,
						:rtime    => book.rtime,
						:page     => book.page,
						:pages    => book.pages,
						:exists   => book.exists,
					}
				}
				File.binwrite( @db_savepath, JSON.pretty_generate( db ) )
				
				@db_dirty = false

				puts "db saved (#{db.length} books) #{Time.now}" if $debug
			end
		end

		# save bookmarks
		def save_bookmarks
			if @bookmarks_dirty
				# save bookmarks
				if ! FileTest.exists?( File.dirname( @bookmarks_savepath ) )
					FileUtils.mkdir_p( File.dirname( @bookmarks_savepath ) )
				end

				bookmarks = {}
				@db.each { |bookcode, book|
					page = book.page  # last read page
					time = book.rtime # last read time

					if page and page > 1
						dat = {
							:p => page,
							:r => time
						}
						bookmarks[bookcode] = dat
					end
				}
				
				File.binwrite( @bookmarks_savepath, JSON.pretty_generate( bookmarks ) )
				
				@bookmarks_dirty = false

				puts "bookmarks saved (#{bookmarks.length} bookmarks) #{Time.now}" if $debug
			end
		end



		private

		# clean up and sanity check on directory lists
		def cleanup_srcs( dir_lists )
			srcs = dir_lists.collect { |src|
				pn = Pathname.new( src )
				fp = pn.expand_path.cleanpath.to_s
			
				if FileTest.directory?( fp ) and not restricted_dir?( fp )
					fp
				end
			}
			srcs.compact!
			p srcs if $debug
			
			srcs
		end

		# generate a unique bookcode, lookup bookcode existance by using db
		def gen_bookcode
			while true
				word = GenChar(3)
				break unless @bookcodes.include?(word) # find next available word
			end
			return word
		end

		# load database
		def load_database
			@db = {}
			
			# indexes for db, help to speed up database search
			@files = {} # hash of files linked to bookcodes, format: files[basename] = bookcode
			@bookcodes = [] # list of bookcodes, format: [ bookcode_a, bookcode_b, bookcode_c, ... ]
			@inodes = {} # list of file inodes, format: inodes[inode] = bookcode

			str = File.binread( @db_savepath )

			JSON.parse( str ).each { |bookcode, h|
				o = Kamishibai::Book.new
				o.bookcode = bookcode
				o.title    = h['title']
				o.author   = h['author']
				o.fullpath = h['fullpath']
				o.size     = h['size']
				o.mtime    = h['mtime']
				o.inode    = h['inode']
				o.itime    = h['itime'] # imported time
				o.rtime    = h['rtime'] # last read time
				o.page     = h['page']  # last read page
				o.pages    = h['pages']

				unless o.pages
					puts "Book contain no images!!! skipping... #{bookcode} #{o.fullpath}"
					next
				end

				@db[ o.bookcode ] = o
				# update indexes
				@files[ File.basename( o.fullpath ).delete('ÿ') ] = o.bookcode # utf8-mac puts ÿ in filename, need to remove first for cross os support
				@inodes[ o.inode ] = o.bookcode

				# if book exists
				if File.exists?( o.fullpath )
					fs = File.stat( o.fullpath )
					o.exists = true

					# repopulate data if doesn't exist
					o.title    = Kamishibai::CBZFilename.title( o.fullpath )  unless o.title
					o.author   = Kamishibai::CBZFilename.author( o.fullpath ) unless o.author
					o.size     = fs.size                                      unless o.size
					o.mtime    = fs.mtime                                     unless o.mtime
					o.inode    = fs.ino                                       unless o.inode

					# update indexes
					@bookcodes << o.bookcode
					@inodes[ o.inode ] = o.bookcode
				end
			}
			
			# db format:   @db[ bookcode ] = Book obj
			# + indexes    @files = { basename_a => bookcode_a, basename_b => bookcode_b, ... }
			#              @bookcodes = [ bookcode_a, bookcode_b, ... ]
			#              @inodes = { inode_a => bookcode_a, inode_b => bookcode_b, ... }
		end

		# load bookmarks
		def load_bookmarks
			bookmarks = {}

			str = File.binread( @bookmarks_savepath )

			JSON.parse( str ).each { |bookcode, h|
				if get_book( bookcode )
					get_book( bookcode ).page  = h['p']
					get_book( bookcode ).rtime = h['r']
				end
			}
		end
	end
end
