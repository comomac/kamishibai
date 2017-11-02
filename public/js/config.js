/*!
License: refer to LICENSE file
 */
 
/*
 * On page load functions
 */

// global variables
var g_prefs = new Object();
var hasFocus = false;

$(function(e) {
	// on page init	

	// load the text localization
	reload_locale();
	
	// load drives
	for (i in drives) {
		var c = "load_dir('" + drives[i] + "/')";
		$('#drives').append("<button class='btn' onclick=\"" + c + ";\">" + drives[i] + "</span>");
	}

	load_dirs();
	
	// refresh # of books every 6 seconds
	interval_total_books = setInterval( function() { total_books(); }, 6000 );
});

// know if browser tab is focused or not
$(window).focus(function() {
    hasFocus = true;
})
.blur(function() {
    hasFocus = false;
});

function load_dirs() {	
	$.getScript("/config?get=srcs", function(data) {
		var dirs = eval(data);

		for (i in dirs) {
			af_add_dir( dirs[i] );
		}
	});
}

function total_books() {
	if (hasFocus) {
		$.get("/config?get=total_books", function(data) {
			$('#total_books').html(data + '&nbsp;');
		});
	}
}

/*
 * Preference functions
 */


function pref_load() {
	$.getScript("/config?get=prefs", function(data) {
		if (data != "") {
			$('#new_book_days').val( g_prefs['new_book_days'] ).prop('disabled',false);
			$('#port').val( g_prefs['port'] ).prop('disabled',false);
			$('#username').val( g_prefs['user'] ).prop('disabled',false);
			$('#password').val( g_prefs['pass'] ).prop('disabled',false);
			$('#img_quality').val( g_prefs['quality'] ).prop('disabled',false);
			
			if ( g_prefs['resize'] ) {
				$('[name=img_resize]').val('on');
			}
			else {
				$('[name=img_resize]').val('off');
			}
			$('#img_resize').prop('disabled',false);
			
			$('#pref-save').prop('disabled',false);
		}
	});
}

function pref_save() {
	var port = $('#port').val();
	if ( port < 1024 || port >= 65535 ) {
		alert( $('#alertPort').text() );
		return false;
	}
	
	var quality = $('#img_quality').val();
	if ( quality < 0 || quality > 100 ) {
		alert( $('#alertImageQuality').text() );
		return false;
	}
			
	// redirect page if port is different
	if ( parseInt( g_prefs['port'] ) != parseInt( $('#port').val() ) ) {
		var wdl = window.document.location;
		setTimeout( function() {
			// window.location.href = wdl.protocol + '//' + wdl.hostname + ':' + nport + wdl.pathname;
			window.location.href = wdl.protocol + '//' + wdl.hostname + ':' + nport + '/';
		}, 1500);
	}

	// go back to browse
	setTimeout(function() {
		window.location.href = '/';
	}, 1600);
	
	$.post("/config", {
		set: 'prefs',
		port: port,
		user: $('#username').val(),
		pass: $('#password').val(),
		resize: $('#img_resize').val(),
		quality: quality,
		new_book_days: $('#new_book_days').val()
	});
}

/*
 * Add Folder Dialog functions
 */
function af_close() {
	$('#addfolder').css('display','none');
}

function load_dir(dir) {
	$('#af-dirnav').fileTree(
		{
			root: dir,
	        script: '/jqueryFileTree',
	        expandSpeed: 1,
	        collapseSpeed: 1,
	        multiFolder: false
		}, function(file) {
	        alert(file);
    	}
    );
}

// dir selected from filetree
function selected_dir(dir) {
	$('#path').val(dir);
}

// Add Folder
function af_add_dir(dir) {
	var elem = $('<tr/>');
	
	$('<td/>',{
		'class': 'c1 srcdir',
		'text': dir
	}).appendTo(elem);
	
	$('<td/>',{
		'class': 'c2',
		'html': '<a href="#" onclick="af_rm_dir(this);" data-localize="config.RemoveFolder"></a>'
	}).appendTo(elem);

	elem.appendTo('tbody');	

	reload_locale();
}

// Remove Folders
function af_rm_dir(elem) {
	$( $(elem) ).parent().parent().remove();
}

// Save Folders (to SRCS)
function save_dirs() {
	var elems = $('.srcdir');
	var dirs = '';
	
	for (var i=0; i < elems.length; i++) {
		dirs += elems.eq(i).text() + '||||';
	}

	// go back to browse
	setTimeout(function() {
		window.location.href = '/';
	}, 1600);
	
	$.post("/config", {
		set: 'srcs',
		srcs: dirs
	});
}
