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
	# run save every 60 seconds
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
			# puts "************* Start Generating Thumbnails *************" 
			
			paused_msg = false
			for bookcode, obj in $db.books
				# generate thumbnails if web request didnt happen for 60 seconds
				if Time.now.to_i > $last_user_interaction_epoch + 10
					mk_thumb( obj.fullpath, true )
					paused_msg = false
				else
					unless paused_msg
						paused_msg = true
						puts "Thumbnail generating paused."
					end
					sleep 1
				end
			end
			
			# puts "************* Finish Generating Thumbnails *************"
			sleep 6
		end
	}
end

# worker thread for webserver
def start_web_server
	return Thread.new {
		Kamishibai::Webserver.run!
	}
end
