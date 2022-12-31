# encoding: utf-8

# License: refer to LICENSE file

module Kamishibai
	class Webserver

		post '/api/book/delete' do
			bookcode = request['bookcode'].untaint

			fp = $db.get_book(bookcode).fullpath

			trash_dir = File.dirname( fp ) + '/Trash'

			unless FileTest.directory?( trash_dir )
				unless File.stat( File.dirname(fp) ).writable?
					halt "Error. Directory is read only! #{ File.dirname(fp) }"
				end

				Dir.mkdir( trash_dir )
			end

			# "#{fp}  ...   #{trash_dir}"
			File.rename( fp, trash_dir + '/' + File.basename(fp) )

			"deleted #{File.basename(fp)}"
		end
	end
end
