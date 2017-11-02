# encoding: utf-8

# License: refer to LICENSE file

module Kamishibai
	class Webserver

		# configuration page, get mode
		get '/config' do
			if request['get']
				case request['get']
					when 'srcs'
						# get list of sources
						content_type :javascript
						$settings.srcs.to_s
					when 'prefs'
						content_type :javascript

						"g_prefs['port'] = #{ $settings.port };\n" +
						"g_prefs['new_book_days'] = #{ $settings.new_book_days };\n" +
						"g_prefs['user'] = \"#{ $settings.username }\";\n" +
						"g_prefs['pass'] = \"#{ $settings.password }\";\n" +
						"g_prefs['resize'] = #{ $settings.image_resize };\n" +
						"g_prefs['quality'] = #{ $settings.default_image_quality };\n"

					when 'total_books'
						# get number of books in db
						content_type :javascript
						$db.books.length.to_s
				end
			else
				haml :config, :layout => false
			end
		end
		

		# configuration page, set mode
		post '/config' do
			if request['set']
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
				end
			end
		end
		
	end
end
