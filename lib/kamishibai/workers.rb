# encoding: utf-8

# License: refer to LICENSE file

require 'thread'

# worker thread for saving database and bookmarks
def start_auto_save
	# run save every 60 seconds
	Thread.new {
		while true
			$db.save
			sleep 60
		end
	}
end


# worker thread for generating thumbnails
def start_auto_gen_thumbnail
	$last_user_interaction_epoch = 0

	Thread.new {
		puts "************* Start Generating Thumbnails *************" 
		
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
		
		puts "************* Finish Generating Thumbnails *************"
	}
end
