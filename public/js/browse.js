/*!
License: refer to LICENSE file
 */


// global variables
var hasTouch = 'ontouchstart' in window; //find out if device is touch device or not
var items_in_row = 0; // number of items in a row (inside #container)
var lastbook = getHashParams()['lastbook'];
if (!lastbook) lastbook = '';
var isBookSelectMode = false;
var isMobile = navigator.userAgent.match(/(iPad)|(iPhone)|(iPod)|(android)|(webOS)/i)
var primary_list;
var last_window_width = window.innerWidth;
var isDeleteMode = false;

// set the last browse selected on cookie
$.cookie(uport() + '.lastbrowse', '/browse/', { path: '/' });

// detect os
var OSName="Unknown OS";
if (navigator.appVersion.indexOf("Win")!=-1) OSName="Windows";
if (navigator.appVersion.indexOf("Mac")!=-1) OSName="MacOS";
if (navigator.appVersion.indexOf("X11")!=-1) OSName="UNIX";
if (navigator.appVersion.indexOf("Linux")!=-1) OSName="Linux";


//window.console||(console={log:function(){}});
// add support to console.log if the browser doesn't support it
if (!console.log) {
	console = {
		log:function(str) {
			window.console.log(str);
		}
	}
}

function homepage() {
	// get dir from hash
	var hashes = getHashParams();
	var dir = hashes['dir'].split('/');

	dir.pop();

	window.location.hash = 'dir=' + dir.join('/')
	return false;
}

function exe_order_by(str) {
	// toggle the order button
	$('.nav-collapse').collapse('toggle');
	
	$.cookie(uport() + '.order_by', str, { path: '/' });

	reload_dir_lists( getHashParams()['dir'], $('#searchbox').val() );
}

function reload_sources() {
	var ul = $('#ul-sources');
	ul.empty();

	$.getScript('/list_sources', function() {
		for (i in sources) {
			ul.append('<li><a tabindex="-1" href="#dir=' + sources[i] + '" rel="' + sources[i] + '">' + i + '&nbsp;<i class="icon-bookmark"></i>&nbsp;' + sources[i] + '</a></li>');
		}
	});
}

function func_set_last_selected_item( str ) {
	$.cookie(uport() + '.last_selected_item', str, { path: '/' });
}

function reload_dir_lists(dir_path, keyword) {
	// set default to name for order_by
	var order_by = 'name';
	var co = $.cookie(uport() + '.order_by');
	if ( co ) {
		switch ( co ) {
			case 'name':
			case 'size':
			case 'date':
				order_by = co;
				break;
		}
	}	
	$.cookie(uport() + '.order_by', order_by, { path: '/' }) ;

	// set the last path selected on cookie
	$.cookie(uport() + '.lastpath', dir_path, { path: '/' });

	var el = $('#dir_lists');
	el.empty();

	$.post('/lists_dir', { dir: dir_path, keyword: keyword, order_by: order_by }, function(data) {
		el.append(data);

		// make li evenly horizontally filled
		var window_width = $(window).innerWidth();
		var li_width = $('.updir').eq(0).innerWidth();
		var num = parseInt(window_width / li_width);
		num = parseInt(window_width / num);
		$('.directory, .file').css('width', num +'px');

		// set container top height
		container_height_refresh();

		// replace all links to desktop reader
		if (!hasTouch) {
			for (i in el.find('LI A')) {
				var el_a = el.find('LI A').eq(i);
				if (el_a.parent().hasClass('file')) {
					el_a.attr('href', el_a.attr('href').replace(/reader2/,'reader') );
				}
			}
		}

		// make images load only when scrolled into view
		$("img.lazy").lazyload({
			//effect : "fadeIn",
			threshold : 500
		});

		// get to the last selected item
		var el_lsi = $('span:contains("' + $.cookie(uport() + '.last_selected_item') + '")').parent();
		if (el_lsi.length == 1) {
			$(el_lsi).addClass('last-selected-item');
			$(document).scrollTo( el_lsi, {offset: - $('.navbar-inner').height() } );
		}

		// apply click event for directory and file, so it will be focused next time
		$('li.directory > a, li.file > a').click( function() {
			func_set_last_selected_item( $(this).text() );
		});
		$('.updir > a').click( function() {
			func_set_last_selected_item( getHashParams()['dir'].split('/').pop() );
		});

		// make sure files are deleteable if in delete mode
		if (isDeleteMode) {
			delete_enable();
		}

		// trigger scroll event, so the img.lazy show thumbnails
		$(window).scroll();
	});
}

function delete_book(bookcode) {
	// send delete bookcode command to server
	$.post('/delete_book', { bookcode: bookcode });
}

function toggleDelete( el ) {	
	var bookcode = el.attr('bookcode');
	
	var el = $('[bookcode=' + bookcode + ']');

	if (el.children('.countdown').length < 1) {
		el.prepend("<div class='countdown'><p>Z</p></div>");

		countdownDelete( el, 6 );
	}
	else {
		var timer = el.attr('timer');
		clearTimeout( timer );

		el.children('.countdown').remove();
	}
}

function countdownDelete(el, time) {
	time = time - 1;

	if (time > 0) {
		// count down reduce by 1
		el.children('.countdown').children('p').text(time);

		var timer = setTimeout( function() {
			countdownDelete(el, time);
		}, 1000);

		el.attr('timer', timer);
	}
	else {
		// count down over, now delete book
		el.removeAttr('timer');

		var bookcode = el.attr('bookcode');
		delete_book(bookcode);

		el.fadeOut( "slow", function() {
			// show trash if doesn't exist, change trash icon to full
			var t = $('#trash');

			if (t.length <= 0) {
				var li_link = getHashParams()['dir'] + '/Trash/';
				var li_trash = '<li class="directory collapsed trash" id="trash"><a href="#dir=' + li_link + '"><img src="/images/trash-full-mini.png" /><span>Trash</span></a></li>'
				$('#ul-lists').append(li_trash);
			}
			else {
				var img = t.find('img').attr('src').split('/').pop();

				if (img == 'trash-empty-mini.png') {
					t.find('img').attr('src', '/images/trash-full-mini.png');
				}
			}
		});
	}
}

function delete_enable() {
	isDeleteMode = true;

	$('.nav-collapse').collapse('toggle');

	var el = $('#btnDeleteDisable');
	el.removeClass('hidden');
	el.show();

	// replace click event to toggle delete
	el = $('li.file > a');
	el.attr('onclick','').unbind('click');
	el.click( function() {
		toggleDelete( $(this) );

		return false;
	});
}

function delete_disable() {
	isDeleteMode = false;

	$('[timer]').each(function() {
		var timer = $(this).attr('timer');
		clearTimeout( timer );

		$(this).children('.countdown').remove();
	});

	var el = $('#btnDeleteDisable');
	el.hide();
	el.addClass('hidden');

	// restore remember last clicked item
	el = $('li.file > a');
	el.attr('onclick','').unbind('click');
	el.click( function() {
		func_set_last_selected_item( $(this).text() );
	});	

}


function container_height_refresh() {
	// $('#container').css('top', $('#navtop').outerHeight() - $('#navcollapse').outerHeight() );
}

function reload_path_label(dir) {
	// set container top height
	container_height_refresh();
}

$(document).keydown(function(e) {
	/* escape key */
	if (e.keyCode == 27) {
		homepage();
		return false;
	}
});

// change dir on hashchange
window.addEventListener("hashchange", function() {
	// get dir from hash
	var hashes = getHashParams();
	var dir = hashes['dir'];

	// stop if dir not defined
	if (dir == undefined) {
		return false;
	}

	// get keyword from searchbox
	var keyword = $('#searchbox').val();

	// save keyword used for search
	$.cookie(uport() + '.lastsearch', keyword, { path: '/' });

	// update path label
	var dirs = dir.split('/');
	dirs.shift();
	var el = '';
	var ds;
	for (var i = 0; i < dirs.length - 1 ; i++) {
		var li_class = '';
		if (i >= dirs.length) {
			li_class = ' class="active"';
		}

		ds = '/';
		for (var j = 0; j < i; j++) {
			ds += dirs[j] + '/';
		}
		ds += dirs[i];
		el += '<li' + li_class + '><a href="#dir=' + ds + '">' + dirs[i] + '</a></li>';
	}
	el += '<li' + li_class + '>' + dirs[i] + '</li>';
	$('#path').html(el);

	// reload the dir list
	reload_dir_lists(dir, keyword);
});

// page init
$(function() {
	// load the text localization
	reload_locale();

	// load sources for menu
	reload_sources();

	if ($.cookie(uport() + '.lastsearch')) {
		$('#searchbox').val( $.cookie(uport() + '.lastsearch') );
	}

	$('#searchbox').bind('change', function(e) {
		// get dir from hash
		var hashes = getHashParams();
		var dir = hashes['dir'];

		// get keyword from searchbox
		var keyword = $('#searchbox').val();

		// stop if it the search is same as last search
		if (keyword == $.cookie(uport() + '.lastsearch')) return false;

		// save keyword used for search
		$.cookie(uport() + '.lastsearch', keyword, { path: '/' });

		// reload the dir list
		reload_dir_lists(dir, keyword);
	});
	$('#searchbox').bind('keyup', function(e) {
		e = e || window.event;

		if (e.keyCode == 13 || e.keyCode == 27) {
			// enter key || escape key, unfocus the searchbox
			$('#searchbox').blur();
		}

		// get dir from hash
		var hashes = getHashParams();
		var dir = hashes['dir'];

		// get keyword from searchbox
		var keyword = $('#searchbox').val();

		// stop if it the search is same as last search
		if (keyword == $.cookie(uport() + '.lastsearch')) return false;

		// save keyword used for search
		$.cookie(uport() + '.lastsearch', keyword, { path: '/' });

		// reload the dir list
		reload_dir_lists(dir, keyword);
	});

	// load dir and file list
	setTimeout( function() {
		setTimeout(function() {
			// set container top height, make sure it runs after everything
			container_height_refresh();
		}, 100);


		// set hash to nothing first, then shortly after the correct hash path will be load, so the dir list will be run
		window.location.hash = '';

		setTimeout(function() {
			if ($.cookie(uport() + '.lastpath')) {
				// load last path remembered
				window.location.hash = '#dir=' + $.cookie(uport() + '.lastpath');
			}
			else {
				// click the first source if there is no lastpath
				window.location.hash = $('#ul-sources').find('LI A').eq(0).attr('href');
			}
		}, 50);

	}, 500);
});

