# encoding: utf-8

# License: refer to LICENSE file

module Kamishibai
	class Webserver
		helpers do
		end

		# show all unique titles
		post '/lists' do
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
		post '/nlists' do
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
		post '/rlists' do
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
		post '/flists' do
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

		# show all unique titles
		post '/alists' do
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

		# list books ver2
		get '/listbooks' do
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

	end
end
