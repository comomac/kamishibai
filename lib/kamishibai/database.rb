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
		attr_reader :files, :bookcodes, :books

		def initialize( db_filepath, bookmarks_filepath )
			@db_savepath = db_filepath
			@db_dirty = true

			if File.exists?( @db_savepath ) and File.size( @db_savepath ) > 0
				load_database
			else
				# create fresh database
				@books = {}
				# indexes
				@bookcodes = []
				@files = {}
				@inodes = {}
			end

			# bookmark section
			@bookmarks_savepath = bookmarks_filepath

			# restore bookmark
			if File.exists?( @bookmarks_savepath )
				bookmarks = read_bookmarks
				bookmarks.keys.each { |bookcode|
					h = bookmarks[bookcode]
					o = get_book(bookcode)
					next unless o
					o.page  = h['p']
					o.rtime = h['r']
				}
				if bookmarks.length > 0
					@db_dirty = true
				end
			end
		end

		def has_bookcode?(bookcode)
			@bookcodes.include?( bookcode )
		end

		def get_book(bookcode)
			@books[ bookcode ]
		end

		def get_book_byfilename(filename)
			filename = File.basename( filename )
			bookcode = @files[ filename ]
			get_book( bookcode )
		end

		def set_bookmark(bookcode, page)
			puts "set_bookmark #{bookcode} #{page}" if $debug
			o = get_book(bookcode)
			o.page  = page
			o.rtime = Time.now.to_i
			@db_dirty = true

			save_bookmarks(o)
		end

		def get_bookmark(bookcode)
			get_book( bookcode ).page
		end

		# basic db stats
		def get_stats
			# WARNING, might cause issue because iteration (.collect/.each) may break during @db modification
			# e.g.  <error> can't add a new key into hash during iteration (RuntimeError)
			return {
				totalBooks:      @books.length,
				totalPages:      @books.collect { |bc, b| b.pages }.reduce( :+ ).to_i,
				pagesRead:       @books.collect { |bc, b| b.page if b.page }.compact.reduce( :+ ).to_i,
				booksRead:       @books.collect { |bc, b| b.page if b.page }.compact.length,
				booksUnfinished: @books.collect { |bc, b| true if b.page && b.page < b.pages }.compact.length,
				recentReadings:  [].join(", "),
				favAuthors:      [].join(", "),
			}
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

				count = 0
				Dir.glob(File.expand_path(src).escape_glob + search).delete_if { |f|
					restricted_dir?(f)
				}.each { |f|
					o = get_book_byfilename( f )
					fs = File.stat(f)
					o2 = get_book( @inodes[ fs.ino ] )

					if o
						# book exists in db
						puts "book match(m1):     #{File.basename(f)} == #{File.basename(o.fullpath)}" if $debug
						
						# update data with new path
						o.fullpath = f
						o.exists   = true

						# update index, as bookcodes is the list that keeps actual books that exists
						@bookcodes << o.bookcode

						@db_dirty = true
					elsif o2 and fs.size == o2.size
						# found existing book using inode and size, can detected changed filename in same filesystem
						puts "book match(m2):     #{File.basename(f)} == #{File.basename(o2.fullpath)}" if $debug

						o2.fullpath = f
						o2.title    = Kamishibai::CBZFilename.title( f )
						o2.author   = Kamishibai::CBZFilename.author( f )
						o2.exists   = true

						# update indexes
						@bookcodes << o2.bookcode
						@files[ File.basename(f) ] = o2.bookcode

						@db_dirty = true
					else
						# book don't exist in db
						# create new
						puts "new book (nm):      #{File.basename(f)}" if $debug

						# make sure it is cbz
						pages = cbz_pages?(f)
						if pages.to_i <= 0
							puts "skip - not cbz file or no image(s). #{f}"
							next
						end

						fs = File.stat( f )

						# create new book object for db
						o = Kamishibai::Book.new(
							:bookcode => gen_bookcode,
							:fullpath => f,
							:title    => Kamishibai::CBZFilename.title( f ),
							:author   => Kamishibai::CBZFilename.author( f ),
							:exists   => true,
							:pages    => pages,
							:size     => fs.size,
							:mtime    => fs.mtime,
							:inode    => fs.ino
						)

						# update indexes
						@books[ o.bookcode ] = o
						@bookcodes << o.bookcode
						@files[ File.basename(f) ] = o.bookcode
						@inodes[ o.inode ] = o.bookcode

						puts "   added book. #{o.bookcode}" if $debug

						@db_dirty = true
					end

					# save every 100th
					count += 1
					if count % 100 == 0
						self.save
					end
				}
			end

			puts "Found #{@bookcodes.length} books" if $debug
		end

		# save database
		def save(force=false)
			force = true if @db_dirty
			return unless force
			
			# create dir if dir doesn't exist
			if ! FileTest.exists?( File.dirname( @db_savepath ) )
				FileUtils.mkdir_p( File.dirname( @db_savepath ) )
			end

			# load bookmarks file
			bookmarks = read_bookmarks
			
			# save db (big file)
			db = {}
			@books.keys.each { |bookcode|
				book = @books[bookcode]
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
					:pages    => book.pages
				}

				# overwrite with bookmark
				if bookmarks[ bookcode ]
					db[ bookcode ][:page]  = bookmarks[ bookcode ][:page]
					db[ bookcode ][:rtime] = bookmarks[ bookcode ][:rtime]
				end
			}
			File.binwrite( @db_savepath, JSON.pretty_generate( db ) )
			@db_dirty = false

			# clear bookmarks file if there is any
			if bookmarks.length > 0
				File.binwrite(@bookmarks_savepath, "{}")
			end

			puts "save db done. #{db.length} books. #{Time.now}" if $debug
		end

		# save bookmarks
		# provide one book, but save with all other books(marks)
		def save_bookmarks(book)
			# load bookmarks file
			bookmarks = read_bookmarks

			# then overwrite it
			bookmarks[ book.bookcode ] = {
				:p => book.page,
				:r => book.rtime
			}
			
			File.binwrite( @bookmarks_savepath, JSON.fast_generate( bookmarks, :object_nl=>"\n", :indent=>" " ) )
			
			puts "bookmarks saved (#{bookmarks.length} bookmarks) #{Time.now}" if $debug
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
			@books = {}
			
			# indexes for db, help to speed up database search
			@files = {} # hash of files linked to bookcodes, format: files[basename] = bookcode
			@bookcodes = [] # list of bookcodes, format: [ bookcode_a, bookcode_b, bookcode_c, ... ]
			@inodes = {} # list of file inodes, format: inodes[inode] = bookcode

			str = File.binread( @db_savepath )

			JSON.parse( str ).each { |bookcode, h|
				o = Kamishibai::Book.new(
					:bookcode => bookcode,
					:title    => h['title'],
					:author   => h['author'],
					:fullpath => h['fullpath'],
					:size     => h['size'],
					:mtime    => h['mtime'],
					:inode    => h['inode'],
					:itime    => h['itime'], # imported time
					:rtime    => h['rtime'], # last read time
					:page     => h['page'],  # last read page
					:pages    => h['pages'],
				)

				@books[ o.bookcode ] = o
				# update indexes
				@files[ File.basename( o.fullpath ).delete('ÿ') ] = o.bookcode # utf8-mac puts ÿ in filename, need to remove first for cross os support
				@bookcodes << o.bookcode
				@inodes[ o.inode ] = o.bookcode
			}
			puts "load db done. #{@books.length} books #{Time.now}"
			
			# books format:   @books[ bookcode ] = Book obj
			# + indexes    @files = { basename_a => bookcode_a, basename_b => bookcode_b, ... }
			#              @bookcodes = [ bookcode_a, bookcode_b, ... ]
			#              @inodes = { inode_a => bookcode_a, inode_b => bookcode_b, ... }
		end

		# load bookmarks file (small), more upto date
		def read_bookmarks
			# create dir
			if ! FileTest.exists?( File.dirname( @bookmarks_savepath ) )
				FileUtils.mkdir_p( File.dirname( @bookmarks_savepath ) )
			end

			bookmarks = {}
			newfile = false
			# create file
			if ! FileTest.exist?( @bookmarks_savepath ) or File.size( @bookmarks_savepath ) == 0
				newfile = true
				File.binwrite( @bookmarks_savepath, "{}" )
			end

			bookmarks = {
				# bookcode => {p: 1, r: 1}
			}
			# skip for brand new file
			unless newfile
				str = File.binread( @bookmarks_savepath )
				JSON.parse( str ).each { |bookcode, h|
					bookmarks[ bookcode ] = {
						:page  => h['p'],
						:rtime => h['r']
					}
				}
			end

			puts "read bookmarks done. #{bookmarks.length} bookmarks" if $debug

			return bookmarks
		end
	end
end
