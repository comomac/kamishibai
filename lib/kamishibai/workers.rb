# encoding: utf-8

# License: refer to LICENSE file

require 'thread'

def start_add_books
	return Thread.new {
		puts 'adding books... this may take some time to run on first time...'

		# add new files to db
		$db.add_books( $settings.srcs )
	}
end

# worker thread for saving database and bookmarks
def start_auto_save
	# save db every x seconds
	return Thread.new {
		while true
			$db.save
			sleep 60
		end
	}
end

# worker thread for generating thumbnails
def start_auto_gen_thumbnail
	$last_user_interaction_epoch = 0

	return Thread.new {
		loop do		
			paused_msg = true
			for bookcode in $db.bookcodes
				book = $db.get_book(bookcode)
				# generate thumbnails if web request didnt happen for x seconds
				if Time.now.to_i > $last_user_interaction_epoch + 10
					if paused_msg
						paused_msg = false
						puts "Auto thumbnail generation started..."
					end
					mk_thumb( book.fullpath, true )
				else
					unless paused_msg
						paused_msg = true
						puts "Auto thumbnail generation paused..."
					end
					sleep 1
				end
			end
			# slow, overall regen thumb from beginning of db
			# wait longer the larger the db
			wait_time_seconds = ($db.bookcodes.length / 100) * 11
			if wait_time_seconds > 3600
				# max 1 hr
				wait_time_seconds = 3600
			elsif wait_time_seconds < 30
				# min 30 sec
				wait_time_seconds = 30
			end
			sleep wait_time_seconds
		end
	}
end

# worker thread for webserver
def start_web_server
	$webserver_start_time = Time.now

	return Thread.new {
		Kamishibai::Webserver.run!
	}
end
