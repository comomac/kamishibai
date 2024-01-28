# encoding: utf-8

# License: refer to LICENSE file

# init once
if $structBook == nil
	$structBook = Struct.new(:bookcode, :title, :author, :fullpath, :mtime, :itime, :rtime, :size, :inode, :page, :pages, :exists) do
		def initialize(params=nil)
			self.bookcode = params[:bookcode]  if params[:bookcode]
			self.title    = params[:title]     if params[:title]
			self.author   = params[:author]    if params[:author]
			self.fullpath = params[:fullpath]  if params[:fullpath]
			self.size     = params[:size]      if params[:size]
			self.mtime    = params[:mtime]     if params[:mtime]
			self.inode    = params[:inode]     if params[:inode]
			self.itime    = params[:itime]     if params[:itime]
			self.rtime    = params[:rtime]     if params[:rtime]
			self.page     = params[:page]      if params[:page]
			self.pages    = params[:pages]     if params[:pages]

			# populate data if doesn't exist
			self.title    = Kamishibai::CBZFilename.title( self.fullpath )  unless self.title
			self.author   = Kamishibai::CBZFilename.author( self.fullpath ) unless self.author
		end
	end
end

# book class
module Kamishibai
	module CBZFilename
		def self.author(s)
			parse(s)[0]
		end

		def self.title(s)
			parse(s)[1]
		end

		def self.parse(s)
			s = File.basename(s)
			s.gsub!(/_/,' ')
			s.gsub!(/　/u,' ')
			s.gsub!(/\(.+?\)/,'')
			author = s.scan(/\[(.+?)\]/)[0][0] if s.scan(/\[(.+?)\]/)[0] and s.scan(/\[(.+?)\]/)[0][0]
			s.gsub!(/\[.+?\]/,'')
			#s.gsub!(/ \S\d+.*/,'')
			s.gsub!(/ \d{4}\S[\d\.]+.+/,'')
			s.gsub!(/ (v|c|第)[\d\.]+.*/iu,'')
			s.gsub!(/ vol.{0,2}[\d\.]+.*/i,'')
			s.gsub!(/ (上|中|下)\.cbz/iu,'.cbz')
			s.gsub!(/ \#[\d\.]+.*/i,'')
			s.gsub!(/ ch.{0,2}[\d\.]+.*/i,'')
			s.gsub!(/ +/,' ')
			s.gsub!(/^ /,'')
			s.gsub!(/\.cbz$/,'')
			s.gsub!(/ $/,'')
			s.gsub!(/ [\d\.]+$/,'')
			title = s

			[author.to_s, title.to_s]
		end

		private_class_method :parse
	end
	
	Book = $structBook

	# class BookZZZ
	# 	attr_reader :bookcode, :title, :author, :fullpath, :mtime, :itime, :rtime, :size, :inode, :page, :pages, :exists
	# 	attr_writer :bookcode, :title, :author, :fullpath, :mtime, :itime, :rtime, :size, :inode, :page, :pages, :exists

	# 	def initialize(params=nil)
	# 		# blank book obj
	# 		re†urn unless params.class == Hash

	# 		# load from db
	# 		@bookcode = params[:bookcode]  if params[:bookcode]
	# 		@title    = params[:title]     if params[:title]
	# 		@author   = params[:author]    if params[:author]
	# 		@fullpath = params[:fullpath]  if params[:fullpath]
	# 		@size     = params[:size]      if params[:size]
	# 		@mtime    = params[:mtime]     if params[:mtime]
	# 		@inode    = params[:inode]     if params[:inode]
	# 		@itime    = params[:itime]     if params[:itime]
	# 		@rtime    = params[:rtime]     if params[:rtime]
	# 		@page     = params[:page]      if params[:page]
	# 		@pages    = params[:pages]     if params[:pages]

	# 		# populate data if doesn't exist
	# 		@title    = Kamishibai::CBZFilename.title( @fullpath )  unless @title
	# 		@author   = Kamishibai::CBZFilename.author( @fullpath ) unless @author
	# 	end
	# end
end