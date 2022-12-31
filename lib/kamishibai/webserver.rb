# encoding: utf-8

# License: refer to LICENSE file

require 'pp' if $debug
require 'sinatra'
require 'sinatra/base'
require 'sinatra/json'
#require 'rack/contrib/try_static'
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
			$db.save_bookmarks
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

			# setup 2nd public location for vendor libraries
			# use Rack::TryStatic,
			# 	:root => File.expand_path(settings.views + '/../public/vendor'),
			# 	:urls => %w[/], try: ['.html', 'index.html', '/index.html']


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

			# regular expression from POST keyword search
			def pregex
				keyword = request['keyword'].untaint
				keyword = keyword.gsub(' ','.+')
				return Regexp.new( keyword, Regexp::IGNORECASE )
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
			jdat = {
				totalBooks:      $db.books.length,
				totalPages:      $db.books.collect { |bc, b| b.pages }.reduce( :+ ),
				pagesRead:       $db.books.collect { |bc, b| b.page if b.page }.compact.reduce( :+ ),
				booksRead:       $db.books.collect { |bc, b| b.page if b.page }.compact.length,
				booksUnfinished: $db.books.collect { |bc, b| true if b.page && b.page < b.pages }.compact.length,
				readingTime:     -1,
				recentReadings:  [].join(", "),
				favAuthors:      [].join(", "),
				uptime:          -1,
				totalUptime:     -1,
			}
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
		post '/api/dir_list' do
			content_type :text
			path = File.expand_path( request['dir'].untaint )
			order_by = request['order_by'].untaint

			unless FileTest.exists?(path)
				errmsg = "Error. No such path. #{path}"
				puts errmsg if $debug
				# not_found errmsg

				return errmsg
			end

			unless File.stat(path).readable_real?
				errmsg = "Error. Not readable path. #{path}"
				puts errmsg if $debug
				# not_found errmsg

				return errmsg
			end

			# check and add new books, existing books will not be added
			$db.add_books( [ path ], false)
			# refresh db, make sure book filepath is valid
			$db.refresh_bookcodes


			html = "<ul id=\"ul-lists\" class=\"ul-lists\">\n"

			html << "\t<li class=\"directory collapsed updir\"><a href=\"#dir=#{File.dirname(path)}\" rel=\"#{File.dirname(path)}/\"><img src=\"/images/folder-mini-up.png\" /><span>..</span></a></li>\n"



			# poulate the lists with files(books) and directory
			lists = []
			Dir.glob(path.escape_glob + '/*').entries.sort.each { |fp|
				next unless File.stat(fp).readable_real?

				dir = File.dirname(fp)
				f =   File.basename(fp)
				ext = File.extname(fp)[1..-1]

				next unless pregex.match( f ) # skip unless file/dir name match the searchbox's keyword

				if FileTest.directory?(fp) and File.stat(fp).executable_real?
					# a directory
					lists << fp

				elsif ext == 'cbz' and File.stat(fp).readable_real?
					# a file
					
					bookcode = $db.get_bookcode_byfilename( fp )
					unless bookcode
						puts "ERROR: bookcode #{bookcode} not found! skipping to next book..."
						next
					end

					book = $db.get_book( bookcode )

					lists << book
				end
			}

			# sort by order
			lists2 = {}
			case order_by
				when 'size'
					lists.each { |x|

						if x.class == Book
							lists2[x] = x.size
						else
							# x == full path of file or directory
							lists2[x] = 0
						end
					}

					lists2 = lists2.sort { |a, b|	b[1] <=> a[1] }

				when 'date'
					lists.each { |x|
						if x.class == Book
							lists2[x] = x.mtime
						else
							# x == full path of file or directory
							lists2[x] = File.stat(x).mtime.to_i
						end
					}
					lists2 = lists2.sort { |a, b| b[1] <=> a[1] }

				else
					# by name, default
					lists.each { |x|
						if x.class == Book
							lists2[x] = File.basename( x.fullpath )
						else
							# x == full path of file or directory
							lists2[x] = File.basename( x )
						end
					}
					lists2 = lists2.sort { |a, b| a[1] <=> b[1] }
			end

			# create html from lists(2)
			lists2.each { |item, dat|

				if item.class == String
					# a directory

					li_classes = ['directory', 'collapsed']

					if item == 'Trash'
						el_id = 'id="trash"'
						li_classes << 'trash'
						if Dir.glob(item.escape_glob + '/*.cbz').entries.length > 0
							icon = 'trash-full-mini.png'
						else
							icon = 'trash-empty-mini.png'
						end
					else
						icon = 'folder-mini.png'
					end

					html << "\t<li class=\"" + li_classes.join(' ') + "\" #{el_id}><a href=\"#dir=#{item}\" rel=\"#{item}/\"><img src=\"/images/" + icon + "\" /><span>#{File.basename(item)}</span></a></li>\n"

				elsif item.class == Book
					# a file

					book = item
					bookcode = book.bookcode
					fp = book.fullpath
					f = File.basename(fp)
					ext = File.extname(fp)[1..-1]

					img = "<img class='lazy fadeIn fadeIn-1s fadeIn-Delay-Xs' data-original='/api/book/thumb/#{bookcode}' alt='Loading...' />"

					if book.page
						# prepare the value for the visual read progress
						page  = book.page
						pages = book.pages

						bn = (1.0*page/pages)*100
						pc = bn - bn % 10

						# read percentage css class
						if pc > 0
							readstate = 'read' + pc.to_i.to_s
						else
							readstate = 'read5'
						end

						href = '/tablet.html#book=' + bookcode + '&page=' + page.to_s
					else
						readstate = 'read0'
						href = '/tablet.html#book=' + bookcode
					end

					html << "\t<li class=\"file ext_#{ext}\"><a href=\"#{href}\" bookcode=\"#{bookcode}\" rel=\"#{fp}\">#{img}<span class=\"#{readstate}\">#{f.escape_html}</span><span class=\"badge badge-info bookpages\">#{book.pages}</span></a></li>\n"
				end
			}

			return html
		end

		# directory browse page
		post '/jqueryFileTree' do
			content_type :text
			path = request['dir'].untaint

			html = "<ul class=\"jqueryFileTree\" style=\"display: none;\">\n"

			if FileTest.exists?(File.expand_path(path))

				# chdir() to user requested dir (root + "/" + dir)
				Dir.chdir(File.expand_path(path).untaint);

				#loop through all directories
				Dir.glob("*") { |x|
					next unless File.directory?(x.untaint)
					next unless File.stat(x.untaint).readable_real? and File.stat(x.untaint).executable_real?

					fp = path + x
					html << "\t<li class=\"directory collapsed\"><a href=\"#\" rel=\"#{fp}/\" onclick=\"selected_dir('#{fp}');\">#{x.escape_html}</a></li>\n";
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

			# # fake delay
			# Thread.new {
			# 	sleep 7
			# 	$imgNum = 0
			# 	sleep 7
			# 	$imgNum = 0
			# }
			# sleep 1.5 * $imgNum
			# $imgNum -= 1

			if width > 0 and height > 0 and $settings.image_resize
				# resize image
				img_resize( image, width, height, { :quality => quality })
			else
				# give raw
				image
			end
		end

		########################################
		#
		# simple mode - books top menu section
		#
		########################################

		# show all unique titles
		post '/api/books/all' do
			titles = {}
			$db.books.each { |bookcode, book|
				next unless book.fullpath_valid
				next unless book.title
				next unless pregex.match( book.title )

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
			titles = {}
			$db.books.each { |bookcode, book|
				next unless book.fullpath_valid
				next unless book.itime
				next unless Time.now.to_i - book.itime < 3600*24*$settings.new_book_days
				next unless book.title
				next unless pregex.match( book.title )

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
			titles = {}
			$db.books.each { |bookcode, book|
				next unless book.fullpath_valid
				next unless book.page
				next unless book.page < book.pages
				next unless book.title
				next unless pregex.match( book.title )

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
			titles = {}
			$db.books.each { |bookcode, book|
				next unless book.fullpath_valid
				next unless book.page
				next unless book.page == book.pages
				next unless book.title
				next unless pregex.match( book.title )

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
			authors = {}
			$db.books.each { |bookcode, book|
				next unless book.fullpath_valid
				next unless book.author
				next unless pregex.match( book.author )

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

			books = {}

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

					books[bookcode] = {
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

			JSON.pretty_generate( books )
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

		# flush bookmarks from memory to hdd
		get '/save_bookmarks' do
			$db.save_bookmarks
		end
		
		# restart webserver
		get '/restart' do
			$RERUN = true
			Process.kill("TERM", Process.pid)
			'<html><head><meta http-equiv="refresh" content="5; url=/"></head><body>restarting...</body></html>'
		end

		# shutdown kamishibai
		get '/shutdown' do
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
					halt "Error. Directory is read only! #{ File.dirname(fp) }"
				end

				Dir.mkdir( trash_dir )
			end

			File.rename( fp, trash_dir + '/' + File.basename(fp) )

			"deleted #{File.basename(fp)}"
		end

	end
end


# load webserver plug-ins
Dir.glob( settings.root + '/../**/webserver_*.rb' ) { |f|
	require f.gsub('.rb','')
}
