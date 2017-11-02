# encoding: utf-8

# License: refer to LICENSE file

module Kamishibai
	class Webserver

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
		
	end
end
