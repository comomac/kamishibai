# encoding: utf-8

# License: refer to LICENSE file

require 'kamishibai/book'
require 'kamishibai/functions'
require 'kamishibai/database'
require 'kamishibai/webserver'
require 'kamishibai/workers'
require 'kamishibai/patches'


if $settings.srcs.length <= 0
	puts "No directory source loaded, please configure at (user/pass is user/pass) http://127.0.0.1:#{$settings.port}/config"
end	

# function for initialize database
def init_database(extra_dirs=[])
	puts 'initializing database... this may take some time to run on first time...'

	# load or create new db
	$db = Kamishibai::Database.new( $settings.db_path, $settings.bookmarks_path )
	
	# add new files to db
	$db.add_books( $settings.srcs )
end

# initialize whole database and bookmarks
init_database

# worker thread for saving bookmarks
start_auto_save

# worker thread for generating thumbnails
start_auto_gen_thumbnail
