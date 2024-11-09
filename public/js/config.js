/*!
License: refer to LICENSE file
 */
 
/*
 * On page load functions
 */

// global variables
var hasFocus = false;

// on page init
$(function(e) {
	// load the text localization
	reload_locale();
	
	// refresh # of books every 6 seconds
	total_books();
	setInterval(function() {
		if (!hasFocus) return;

		total_books();
	}, 6000);
});

// load drives
$.get("/api/drives").then(function(drives) {
	for (var i in drives) {
		var c = "load_dir('" + drives[i] + "/')";
		$('#drives').append("<button class='btn' onclick=\"" + c + ";\">" + drives[i] + "</span>");
	}
});


// show folders that holds cbz
$.get("/config?get=srcs", function(dirs) {
	for (var i in dirs) {
		af_add_dir( dirs[i] );
	}
});

// know if browser tab is focused or not
// to prevent total_books query when tab not in focus
$(window).focus(function() {
    hasFocus = true;
})
.blur(function() {
    hasFocus = false;
});
// load total books
function total_books() {
	$.get("/config?get=total_books", function(data) {
		$('#total_books').html(data + '&nbsp;');
	});
}

/*
 * Preference functions
 */

function pref_load() {
	$.get("/config?get=prefs", function(jdat) {
		if (!!!jdat) return;

		$('#new_book_days').val( jdat['new_book_days'] ).prop('disabled',false);
		$('#port').val( jdat['port'] ).prop('disabled',false);
		$('#username').val( jdat['user'] ).prop('disabled',false);
		$('#password').val( jdat['pass'] ).prop('disabled',false);
		$('#img_quality').val( jdat['quality'] ).prop('disabled',false);
		
		if ( jdat['resize'] ) {
			$('[name=img_resize]').val('on');
		}
		else {
			$('[name=img_resize]').val('off');
		}
		$('#img_resize').prop('disabled',false);
		
		$('#pref-save').prop('disabled',false);
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
	var elA = document.createElement('A');
	elA.setAttribute('href', window.location.href);
	if ( elA.port !== $('#port').val() ) {
		elA.port = $('#port').val();
		setTimeout( function() {
			window.location.href = elA.href;
		}, 1000);
	}
	
	$.post("/config", {
		set: 'prefs',
		port: port,
		user: $('#username').val(),
		pass: $('#password').val(),
		resize: $('#img_resize').val(),
		quality: quality,
		new_book_days: $('#new_book_days').val()
	}).then(function() {
		// saving too fast, slow down so can see
		setTimeout(function() {
			$('#modal-saving').modal('toggle');
		}, 1000);
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

	$.post("/config", {
		set: 'srcs',
		srcs: dirs
	}).then(function() {
		// saving too fast, slow down so can see
		setTimeout(function() {
			$('#modal-saving').modal('toggle');
		}, 1000);
	});
}
