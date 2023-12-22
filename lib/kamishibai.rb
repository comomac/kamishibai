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
	puts 'initializing database...'

	# load or create new db
	$db = Kamishibai::Database.new( $settings.db_path, $settings.bookmarks_path )
end

# db must be initialized first,
# initialize/load database and bookmarks
init_database

# worker thread for adding books
start_add_books

# worker thread for saving bookmarks
start_auto_save

# worker thread for generating thumbnails
start_auto_gen_thumbnail

# worker thread for serving web requests
th = start_web_server
# keep server thread running
th.join