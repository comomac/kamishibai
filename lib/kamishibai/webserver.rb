# encoding: utf-8

# License: refer to LICENSE file

require 'sinatra'
require 'sinatra/base'
require 'sinatra/json'
require 'rbconfig'

#
# Kamishibai
# A manga reading webapp
#

module Kamishibai
	class Webserver < Sinatra::Base
		# shutdown hook, save database and bookmarks when exiting
		at_exit do
			$db.save
		end

		# smaller, quicker web server
		set :server, 'thin' unless RUBY_PLATFORM == 'java'

		configure do
			# listen to all interface
			set :bind, $settings.bind

			# setup port
			set :port, $settings.port


			# enable session support
			enable :sessions
			use Rack::Session::Pool, :expire_after => 60*60*24*365

			# enable http gzip
			use Rack::Deflater

			# setup template location
			set :views, File.expand_path( settings.root + '/../../views' )

			# setup public location
			set :public_folder, File.expand_path(settings.views + '/../public')

			# authentication
			use Rack::Auth::Basic, "Restricted Area" do |username, password|
				[username, password] == [$settings.username, $settings.password]
			end

			# register mime type for static file
			mime_type :jpeg, 'image/jpeg'
			mime_type :png, 'image/png'
			mime_type :gif, 'image/gif'
			mime_type :css, 'text/css'
			mime_type :html, 'text/html'
			mime_type :javascript, 'application/javascript'
		end

		# setup instance variable
		before do
			# global instance var

			# last any request interaction
			$last_user_interaction_epoch = Time.now.to_i
		end

		# helper functions
		helpers do
			# precheck the input from url
			def input_check( bookcode, page )
				page = page.to_i

				if $db.has_bookcode?( bookcode )
					@book = $db.get_book( bookcode )
				else
					not_found "No such book code. #{ bookcode }"
				end

				unless @book.pages
					not_found "Book contain no images. #{ bookcode } #{ @book.fullpath }"
				end

				if page < 1 or page > @book.pages
					not_found "No such page. #{ page } #{ bookcode } #{ @book.fullpath }"
				end

				if ! FileTest.exists?( @book.fullpath )
					not_found "File don't exists. #{ bookcode } #{ @book.fullpath }"
				end

				if ! FileTest.file?( @book.fullpath )
					not_found "Not a file. #{ bookcode } #{ @book.fullpath }"
				end
			end

			# search_words gives an array of words that user is looking for
			def search_words(keyword='')
				# convert all other white space characters to normal space character
				keyword = keyword.downcase
				for spc in white_space_characters
					keyword = keyword.gsub(spc,' ')
				end

				# words to search for
				return keyword.split(' ').compact
			end

			def white_space_characters
				# white space characters
				# https://en.wikipedia.org/wiki/Whitespace_character
				return [
					"\u{0009}", "\u{0020}", "\u{00a0}", "\u{1680}", "\u{2000}", 
					"\u{2001}", "\u{2002}", "\u{2003}", "\u{2004}", "\u{2004}", 
					"\u{2005}", "\u{2006}", "\u{2007}", "\u{2008}", "\u{2009}", 
					"\u{200a}", "\u{202f}", "\u{205f}", "\u{3000}" 
				]
			end
		end


		# detect screen dimension
		post '/screen' do
			session[:width] = params[:width].to_i
			session[:height] = params[:height].to_i

			puts "screen dimension. #{session[:width]} x #{session[:height]}" if $debug
		end

		# redirect index page
		get '/' do
			redirect '/browse.html'
		end

		get '/api/stats' do
			jdat = $db.get_stats
			jdat[:uptimeSeconds] = (Time.now - $webserver_start_time).to_i

			json jdat
		end

		# remember page read
		post '/api/book/bookmark' do
			bookcode = params[:bookcode].untaint
			page     = params[:page].to_i

			input_check( bookcode, page )

			$db.set_bookmark(bookcode, page)

			"bookmarked"
		end

		# list sources
		get '/api/sources' do
			json $settings.srcs
		end

		get '/api/drives' do
			json available_drives
		end

		# directory browse page
		get '/api/dir_list' do
			content_type :text

			dir = request['dir'] || ""
			unless dir.length > 0
				halt 400, "Error. dir not provided"
			end
			path = File.expand_path( dir )

			order_by = request['order_by'] || ""

			unless FileTest.exists?(path)
				halt 400, "Error. No such dir. #{path}"
			end

			unless File.stat(path).readable_real?
				halt 400, "Error. Not readable dir. #{path}"
			end

			html = %Q[<ul id="ul-lists" class="ul-lists">\n]

			html << %Q[\t<li class="directory collapsed updir"><a href="#dir=#{File.dirname(path)}" rel="#{File.dirname(path)}/"><img src="/images/folder-mini-up.png" /><span>..</span></a></li>\n]

			keyword = request['keyword'] || ""
			keywords = search_words(keyword)

			# poulate the lists with files(books) and directory
			lists = [
				# [ File::Stat, Book ],
				# [ File::Stat, dir(string) ],
			]
			Dir.glob(path.escape_glob + '/*').entries.sort.each { |fp|
				fs = File.stat(fp)
				# skip unreadable file/dir (permission)
				next unless fs.readable_real?

				# search for all keywords
				f =   File.basename(fp)
				found = 0
				for kw in keywords
					if f.downcase.include?(kw)
						found+=1
					else
						# stop early to save cpu cycles
						break
					end
				end
				next if found < keywords.length
			
				if fs.directory? and fs.executable_real?
					# a directory
					lists << [fs, fp]

				elsif File.extname(fp) == '.cbz' and fs.readable_real?
					# a file
					
					book = $db.get_book_byfilename( fp )
					unless book
						puts "ERROR: book not found! #{fp} skipping to next book..." if $debug
						next
					end

					lists << [fs, book]
				end
			}

			# sort order
			if order_by == 'size'
				# by file size (big to small)
				lists.sort! { |b,a|
					a[0].size <=> b[0].size
				}
			elsif order_by == 'date'
				# by create date (latest to oldest)
				lists.sort! { |b,a|
					a[0].ctime <=> b[0].ctime
				}
			else
				# by file name (a to z)
				lists.sort! { |a,b|
					fa = a[1].class == Book ? File.basename(a[1].fullpath) : a[1]
					fb = b[1].class == Book ? File.basename(b[1].fullpath) : b[1]
					fa<=>fb
				}
			end

			# create html from lists
			lists.each { |fs, item|

				if item.class == String
					# a directory

					li_classes = ['directory', 'collapsed']

					icon = 'folder-mini.png'
					if item == 'Trash'
						el_id = 'id="trash"'
						li_classes << 'trash'
						if Dir.glob(item.escape_glob + '/*.cbz').entries.length > 0
							icon = 'trash-full-mini.png'
						else
							icon = 'trash-empty-mini.png'
						end
					end

					html << %Q[\t<li class="#{li_classes.join(' ')}" #{el_id}><a href="#dir=#{item}" rel="#{item}/"><img src="/images/#{icon}" /><span>#{File.basename(item)}</span></a></li>\n]

				elsif item.class == Book
					# a book (file)

					book = item
					bookcode = book.bookcode

					img = %Q[<img class="lazy fadeIn fadeIn-1s fadeIn-Delay-Xs" data-original="/api/book/thumb/#{bookcode}" alt="Loading..." />]
					href = '/tablet.html#book=' + bookcode
					readstate = 'read'

					if book.page
						# prepare the value for the visual read progress
						page  = book.page
						pages = book.pages

						bn = (1.0*page/pages)*100
						pc = bn - bn % 10

						# read percentage css class
						if pc > 0
							readstate += pc.to_i.to_s
						else
							readstate += '5'
						end

						href += '&page=' + page.to_s
					else
						readstate += '0'
					end

					html << %Q[\t<li class="file ext_cbz"><a href="#{href}&dir=#{path}" bookcode="#{bookcode}" rel="#{book.fullpath}">#{img}<span class="#{readstate}">#{File.basename(book.fullpath).escape_html}</span><span class="badge badge-info bookpages">#{book.pages}</span></a></li>\n]
				end
			}

			html << "</ul>\n"

			# check and add new books, existing books will not be added
			# run in separate thread to speed up, will eventually show all
			# put at the end to speed up serving
			Thread.new {
				sleep 0.5
				$db.add_books( [ path ], false)
			}

			return html
		end

		# directory browse page
		post '/jqueryFileTree' do
			content_type :text
			path = request['dir'].untaint

			html = %Q[<ul class="jqueryFileTree" style="display: none;">\n]

			if FileTest.exists?(File.expand_path(path))

				# chdir() to user requested dir (root + "/" + dir)
				Dir.chdir(File.expand_path(path).untaint);

				#loop through all directories
				Dir.glob("*") { |x|
					fs = File.stat(x.untaint)
					next unless fs.directory?
					next unless fs.readable_real?
					next unless fs.executable_real?

					fp = path + x
					html << %Q[\t<li class="directory collapsed"><a href="#" rel="#{fp}/" onclick="selected_dir('#{fp}');">#{x.escape_html}</a></li>\n]
				}

			end

			html << "</ul>\n"

			return html
		end

		# cbz thumbnail
		get '/api/book/thumb/*' do |bookcode|
			cache_control :public, :must_revalidate, :max_age => 3600

			# check and setup the variable
			input_check( bookcode, 1 )

			content_type :jpeg

			# generate thumbnail
			image = mk_thumb( @book.fullpath )

			return image
		end

		# cbz file loader
		get '/api/book/page/*/*' do |bookcode, page|
			page = page.to_i
			cache_control :public, :must_revalidate, :max_age => 3600

			input_check( bookcode, page )

			# width/height
			quality = $settings.default_image_quality
			width = session[:width].to_i
			height = session[:height].to_i
			# hard set to hd
			# width  = 1080
			# height = 1920

			# fix/prevent invalid input
			quality = 0 if quality < 0
			quality = 100 if quality > 100
			width = 0 if width < 0 # 0 will be treated as do not resize
			height = 0 if height < 0

			# image type, image data
			image = open_cbz( @book.fullpath, page)

			# set content type, png/jpeg/png/gif/etc
			itype = image_type( image )
			content_type itype

			# recompress/resize if needed
			max_file_size = 1024*1024*1.2 # 1.2mb
			max_width  = 1080
			max_height = 1920
			img = re_image(image, quality, max_width, max_height, max_file_size)
			if img == nil
				halt 500, 'image is nil'
			end

			img
		end

		########################################
		#
		# simple mode - books top menu section
		#
		########################################

		# show all unique titles
		post '/api/books/all' do
			keywords = search_words(request['keyword'])

			titles = {}
			$db.books.each { |bookcode, book|
				next unless book.exists
				next unless book.title

				# search for all keywords
				found = 0
				for kw in keywords
					if book.title.downcase.include?(kw)
						found+=1
					else
						# stop early to save cpu cycles
						break
					end
				end
				next if found < keywords.length

				if titles[ book.title ]
					titles[ book.title ] << book.bookcode
				else
					titles[ book.title ] = [ book.bookcode ]
				end
			}

			# sort by title alphabetically
			titles = titles.sort { |a, b| a[0] <=> b[0] }

			jTitles = []
			titles.each { |title, bookcodes|
				jTitles << {
					:title => title,
					:bookcodes => bookcodes
				}
			}

			json jTitles
		end

		# lists containing newly imported books
		post '/api/books/new' do
			keywords = search_words(request['keyword'])

			titles = {}
			$db.books.each { |bookcode, book|
				next unless book.exists
				next unless book.itime
				next unless Time.now.to_i - book.itime < 3600*24*$settings.new_book_days
				next unless book.title

				# search for all keywords
				found = 0
				for kw in keywords
					if book.title.downcase.include?(kw)
						found+=1
					else
						# stop early to save cpu cycles
						break
					end
				end
				next if found < keywords.length

				if titles[ book.title ]
					titles[ book.title ] << book.bookcode
				else
					titles[ book.title ] = [ book.bookcode ]
				end
			}

			# sort by time last imported
			titles = titles.sort { |a, b|
				newest_a = 0
				a[1].each { |bookcode|
					rtime = $db.get_book(bookcode).itime
					newest_a = rtime if rtime and rtime > newest_a
				}

				newest_b = 0
				b[1].each { |bookcode|
					rtime = $db.get_book(bookcode).itime
					newest_b = rtime if rtime and rtime > newest_b
				}

				newest_b <=> newest_a
			}

			jTitles = []
			titles.each { |title, bookcodes|
				jTitles << {
					:title => title,
					:bookcodes => bookcodes
				}
			}

			json jTitles
		end


		# lists books that are unfinish reading
		post '/api/books/reading' do
			keywords = search_words(request['keyword'])

			titles = {}
			$db.books.each { |bookcode, book|
				next unless book.exists
				next unless book.page
				next unless book.page < book.pages
				next unless book.title
				
				# search for all keywords
				found = 0
				for kw in keywords
					if book.title.downcase.include?(kw)
						found+=1
					else
						# stop early to save cpu cycles
						break
					end
				end
				next if found < keywords.length

				if titles[ book.title ]
					titles[ book.title ] << book.bookcode
				else
					titles[ book.title ] = [ book.bookcode ]
				end
			}

			# sort by time last read
			titles = titles.sort { |a, b|
				newest_a = 0
				a[1].each { |bookcode|
					rtime = $db.get_book(bookcode).rtime
					newest_a = rtime if rtime and rtime > newest_a
				}

				newest_b = 0
				b[1].each { |bookcode|
					rtime = $db.get_book(bookcode).rtime
					newest_b = rtime if rtime and rtime > newest_b
				}

				newest_b <=> newest_a
			}

			jTitles = []
			titles.each { |title, bookcodes|
				jTitles << {
					:title => title,
					:bookcodes => bookcodes
				}
			}

			json jTitles
		end

		# lists books that are finish reading
		post '/api/books/finished' do
			keywords = search_words(request['keyword'])

			titles = {}
			$db.books.each { |bookcode, book|
				next unless book.exists
				next unless book.page
				next unless book.page == book.pages
				next unless book.title
				
				# search for all keywords
				found = 0
				for kw in keywords
					if book.title.downcase.include?(kw)
						found+=1
					else
						# stop early to save cpu cycles
						break
					end
				end
				next if found < keywords.length

				if titles[ book.title ]
					titles[ book.title ] << book.bookcode
				else
					titles[ book.title ] = [ book.bookcode ]
				end
			}

			# sort by time last read
			titles = titles.sort { |a, b|
				newest_a = 0
				a[1].each { |bookcode|
					rtime = $db.get_book(bookcode).rtime
					newest_a = rtime if rtime and rtime > newest_a
				}

				newest_b = 0
				b[1].each { |bookcode|
					rtime = $db.get_book(bookcode).rtime
					newest_b = rtime if rtime and rtime > newest_b
				}

				newest_b <=> newest_a
			}

			jTitles = []
			titles.each { |title, bookcodes|
				jTitles << {
					:title => title,
					:bookcodes => bookcodes
				}
			}

			json jTitles
		end

		# show books grouped by author
		post '/api/books/author' do
			keywords = search_words(request['keyword'])

			authors = {}
			$db.books.each { |bookcode, book|
				next unless book.exists
				next unless book.author

				# search for all keywords
				found = 0
				for kw in keywords
					if book.author.downcase.include?(kw)
						found+=1
					else
						# stop early to save cpu cycles
						break
					end
				end
				next if found < keywords.length

				if authors[ book.author ]
					authors[ book.author ] << book.bookcode
				else
					authors[ book.author ] = [ book.bookcode ]
				end
			}

			# sort by author alphabetically
			authors = authors.sort { |a, b| a[0] <=> b[0] }

			jAuthors = []
			authors.each { |author, bookcodes|
				jAuthors << {
					:author => author,
					:bookcodes => bookcodes
				}
			}

			json jAuthors
		end

		# list books with meta-data
		get '/api/books/info' do
			content_type :json

			bookcodes = request['bookcodes'] ? request['bookcodes'].split(',') : []
			options   = request['options']   ? request['options'].split(',') : []

			books = []

			for bookcode in bookcodes
				if $db.has_bookcode?( bookcode )
					book = $db.get_book( bookcode )

					# book volume/chapter/etc info
					bn = File.basename( book.fullpath )
					bn = bn.gsub( File.extname(bn), '' )
					bn = bn.gsub( book.title, '' )
					# bn = bn.gsub( bn.replace(/\'/,'&#39;'), '' )
					bn = bn.gsub( /(\(.+?\))/, '' )
					bn = bn.gsub( /(\[.+?\])/, '' )
					bn = bn.gsub( /(\[\])/, '' )
					bn = bn.gsub( / +/, ' ' )
					bn.strip!

					books << {
						:bookcode => bookcode,
						:title  => book.title,
						:sname  => bn,
						:author => book.author,
						:size   => book.size,
						:mtime  => book.mtime,
						:itime  => book.itime,
						:rtime  => book.rtime,
						:page   => book.page,
						:pages  => book.pages
					}
				end
			end

			# sort by book title if possible
			if bookcodes.length <= 100
				# by title and volume/chapter
				books.sort! { |a,b|
					aa = (%Q[#{a[:title]} #{a[:sname]}]).naturalized.to_s
					bb = (%Q[#{b[:title]} #{b[:sname]}]).naturalized.to_s
					aa > bb ? 1 : 0
				}
			end

			books2 = {}
			books.each { |book|
				books2[book[:bookcode]] = book
			}

			JSON.pretty_generate( books2 )
		end

		########################################
		#
		# configuration page
		#
		########################################

		# read config
		get '/config' do
			case request['get']
				when 'srcs'
					# get list of sources
					json $settings.srcs
				when 'prefs'
					# 
					jdat = {
						port:    $settings.port,
						user:    $settings.username,
						pass:    $settings.password,
						resize:  $settings.image_resize,
						quality: $settings.default_image_quality,
						new_book_days:  $settings.new_book_days,
					}
					json jdat

				when 'total_books'
					# get number of books in db
					content_type :javascript
					$db.books.length.to_s
				else
					'get=?'
			end
		end

		# save config
		post '/config' do
			case request['set']
				when 'srcs'
					# save book sources
					old_srcs = $settings.srcs.collect { |d|
						if d[-1..-1] == '/'
							d[0..-2]
						else
							d[0..-1]
						end
					}.sort

					srcs = request['srcs'].split('||||').compact
					srcs = srcs.collect { |d|
						if d[-1..-1] == '/'
							d[0..-2]
						else
							d[0..-1]
						end
					}.sort
					$settings.srcs = srcs

					$settings.save

					# srcs has changed, reload the whole kamishibai, to reload the db
					if old_srcs != srcs
						init_database
					end
				when 'prefs'
					# save settings
					r = request

					old_port = $settings.port
					$settings.port = r['port'].to_i
					$settings.image_resize = r['resize'] == 'on' ? true : false
					$settings.username = r['user']
					$settings.password = r['pass']
					$settings.new_book_days = r['new_book_days'].to_i
					$settings.default_image_quality = r['quality'].to_i

					$settings.save

					if $settings.port != old_port
						# restart webserver if port is different from old port
						$RERUN = true
						Process.kill("TERM", Process.pid)
					end
				else
					'set=?'
			end
		end

		########################################
		#
		# remote commands
		#
		########################################

		# restart webserver
		post '/restart' do
			if params[:confirm] != 'yes'
				halt 400, 'confirmation needed'
			end

			$RERUN = true
			Process.kill("TERM", Process.pid)
			'<html><head><meta http-equiv="refresh" content="5; url=/"></head><body>restarting...</body></html>'
		end

		# shutdown kamishibai
		post '/shutdown' do
			if params[:confirm] != 'yes'
				halt 400, 'confirmation needed'
			end
			
			$RERUN = false
			Process.kill("TERM", Process.pid)
		end

		# delete file (put into Trash folder)
		post '/api/book/delete' do
			bookcode = request['bookcode'].untaint

			fp = $db.get_book(bookcode).fullpath

			trash_dir = File.dirname( fp ) + '/Trash'

			unless FileTest.directory?( trash_dir )
				unless File.stat( File.dirname(fp) ).writable?
					halt 400, "Error. Directory is read only! #{ File.dirname(fp) }"
				end

				Dir.mkdir( trash_dir )
			end

			File.rename( fp, trash_dir + '/' + File.basename(fp) )

			"deleted #{File.basename(fp)}"
		end

	end
end
