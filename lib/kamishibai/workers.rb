# encoding: utf-8

# License: refer to LICENSE file

require 'thread'

# worker thread for saving database and bookmarks
def start_auto_save
	# run save every 60 seconds
	Thread.new {
		while true
			$db.save
			$db.save_bookmarks
			sleep 60
		end
	}
end


# worker thread for generating thumbnails
def start_auto_gen_thumbnail
	$open_cbz_ltime = Time.now - 61 # holds the last time the open_cbz is called

	Thread.new {
		puts "************* Start Generating Thumbnails *************" 
		
		for bookcode, obj in $db.books
			# if the call to open_cbz has elasped more than 60 seconds, allow to resume generating
			if $open_cbz_ltime + 60 < Time.now
				mk_thumb( obj.fullpath, true )
			else
				puts "Thumbnail generating paused."
				sleep 60
			end
		end
		
		puts "************* Finish Generating Thumbnails *************"
	}
end
