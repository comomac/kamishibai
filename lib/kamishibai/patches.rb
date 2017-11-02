# encoding: utf-8

# License: refer to LICENSE file

require 'addressable/uri' #using addressable because default ruby uri is badly implemented, causing InvalidURIError on many situations, especially unicode string

#
# bug fix
# the addressable/uri has a bug that is not escaping the '
#
class Addressable::URI
	def self.escape2(str)
		s = Addressable::URI.escape(str)
		s = s.gsub("#",'%23')
		s = s.gsub("'",'%27')
		s = s.gsub('+','%2B')
		s
	end
end

class Addressable::URI
	def self.unescape2(str)
		s = str.gsub('%2B','+')
		s = s.gsub('%27',"'")
		s = s.gsub('%23',"#")
		s = Addressable::URI.unescape(s)
		s
	end
end


#
# bug fix
# fixing bug when client post to server it get 405 "Method Not Allowed" Error
# https://github.com/bachue/rack-contrib/commit/f5f4ffebc20277903f6013adfb0429d12b4a3050
#
module Rack
  class TryStatic

    def initialize(app, options)
      @app = app
      @try = ['', *options[:try]]
      @static = ::Rack::Static.new(
        lambda { |_| [404, {}, []] },
        options)
    end

    def call(env)
      orig_path = env['PATH_INFO']
      found = nil
      @try.each do |path|
        resp = @static.call(env.merge!({'PATH_INFO' => orig_path + path}))
		break if !(403..405).include?(resp[0]) && found = resp
      end
      found or @app.call(env.merge!('PATH_INFO' => orig_path))
    end
  end
end