# encoding: utf-8

# License: refer to LICENSE file

require 'json'

#
# Handle global Kamishibal configuration
#
module Kamishibai
	class Config
		attr_reader :config_path, :srcs, :image_resize, :default_image_quality, :username, :password, :bind, :port, :db_path, :bookmarks_path, :cache_path, :new_book_days
		attr_writer :config_path, :srcs, :image_resize, :default_image_quality, :username, :password, :bind, :port, :db_path, :bookmarks_path, :cache_path, :new_book_days

		def initialize( path = '~/etc/kamishibai.conf' )
			@config_path = File.expand_path( path )

			if File.exist?( @config_path )
				load
			else
				# settings template
				@srcs = []
				@image_resize = true
				@default_image_quality = 60
				@username = 'admin'
				@password = 'admin'
				@bind     = '0.0.0.0'
				@port     = 9999

				@db_path        = '~/var/kamishibai/db.json'
				@bookmarks_path = '~/var/kamishibai/bookmarks.json'
				@cache_path     = '~/var/kamishibai/cache/'

				@new_book_days = 7

				save_config
			end
		end

		def save
			unless FileTest.exist?( File.dirname( @config_path ) )
				FileUtils.mkdir_p( File.dirname( @config_path ) )
			end

			t = {}
			t[:srcs]         = @srcs.collect { |src| File.expand_path(src) }
			t[:image_resize] = @image_resize
			t[:default_image_quality] = @default_image_quality
			t[:username] = @username
			t[:password] = @password
			t[:bind]     = @bind
			t[:port]     = @port

			t[:db_path]        = File.expand_path( @db_path )
			t[:bookmarks_path] = File.expand_path( @bookmarks_path )
			t[:cache_path]     = File.expand_path( @cache_path )

			t[:new_book_days] = @new_book_days

			File.binwrite( @config_path, JSON.pretty_generate( t ) )

			puts "config created at #{@config_path}" if $debug
		end

		alias_method :save_config, :save
		
		private

		# load settings from json config file
		def load
			json = JSON.parse( File.binread( @config_path ) )

			@srcs         = json['srcs'].collect { |src| File.expand_path(src) }
			@image_resize = json['image_resize']
			@default_image_quality = json['default_image_quality']
			@username = json['username']
			@password = json['password']
			@bind     = json['bind']
			@port     = json['port']

			@db_path         = File.expand_path( json['db_path'] )
			@bookmarks_path  = File.expand_path( json['bookmarks_path'] )
			@cache_path      = File.expand_path( json['cache_path'] )

			@new_book_days   = json['new_book_days']

			puts "config loaded at #{@config_path}" if $debug
		end
	end
end
