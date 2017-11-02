/*!
License: refer to LICENSE file
 */

// bookcode
var bookcode = getHashParams()['book'];

// initialize book variables
var maxpage;
var booktitle;

// load bookinfo
document.write("<script src=\"/bookinfo/" + bookcode + "\"><\/script>");


// record the cookie
$.cookie('lastbook' + uport(), bookcode, { path: '/' });

// get the hash for the page
function getpage() {
	var i = parseInt( getHashParams()['page'] );

	if (typeof i == "number" && ! isNaN(i) ) {
		return i;
	}

	return -1;
}


$(window).bind('hashchange', function(e) {
	$('#pageslider').slider('value', getpage());
	reload_images();
	preload_images();
});


var $slider_flag = false;


$(function() {
	// page init

	// setup book variable
	maxpage   = book.pages;
	booktitle = book.title;

	// load the text localization
	reload_locale();

	// set book title on menu
	$('#booktitle').html('<h2>' + booktitle + '</h2>');


	// set even/odd tab and min value
	if (getpage() == -1 || getpage() % 2 == 0) {
		$('#pageeven').click();
	}
	else {
		$('#pageodd').click();
	}


	// setup page slider
	$('#pageslider').slider({
        range: 'min',
        min: 0,
        max: maxpage,
        step: 2,
        value: getpage(),
	    slide: function(event,ui) {
	    	$('#pageslider-value').val( ui.value );
	    },
		start: function(event,ui) {
			$slider_flag = true
		},
		stop: function(event,ui) {
			window.location.hash = fullhash( ui.value );
			$slider_flag = false;
		},
		change: function(event,ui) {
			$('#pageslider-value').val( $('#pageslider').slider('value') );

			if ($slider_flag) return false;
			window.location.hash = fullhash( ui.value );
		}
	});
	$('#pageslider-value').val( $('#pageslider').slider('value') );


	if (getpage() == -1) {
		window.location.hash = fullhash( 0 );
	}
	else {
		// wait until jquery ui fully loaded, then setup page, or some stuff isn't displayed properly
		reload_images();
		preload_images();
	}


	/* setup button functions */
	$('#pagemode')
		.buttonset()
		.change(function(e) {
			/* setting using mouse function and a time delay, or it won't work
			 * bug is probably cause by double trigger and transition time, if it is responded immediately, the called radio will still be stuck at previous selection
			 */
			var elem = $('#pageslider');
			if (isSinglePageMode()) {
				// set slider step by 1
				elem.slider('option', 'step', 1);

				// disable set of buttons
				disable_buttons();
			}
			else {
				// set slider step by 2
				elem.slider('option', 'step', 2);

				// enable set of buttons
				enable_buttons();
			}

			// load images
			reload_images();
		});
	$('#itemsheight')
		.buttonset()
		.change(function(e) {
			if (isNormalHeight()) {
				/* change to normal height */
				$('#pagemode').buttonset('enable');
			}
			else {
				/* change to full height */
				$('#singlepage').click();
				$('#pagemode').buttonset('disable');
			}
			reload_images();
		});
	$('#readdirection')
		.buttonset()
		.change(function(e) {
			reload_images();
		});
	$('#primarypage')
		.buttonset()
		.change(function(e) {
			console.log('primary change');

			// making the page even or odd page primary
			if (isEvenPage()) {
				$('#pageslider').slider('option', 'min', 0);
			}
			else {
				$('#pageslider').slider('option', 'min', 1);
			}
			reload_images();
		});
	$('#barmode')
		.buttonset()
		.change(function(e) {
			reload_images();
		});
	$('#closemenu')
		.button()
		.click( function(e) {
			window.setTimeout( function() { hidemenu(); }, 50 );
		});
	$('#gohome')
		.button()
		.click( function(e) {
			window.setTimeout( function() { goHomepage(); }, 50 );
	});

});

function reload_images() {
	window.setTimeout( function() { exec_reload_images(); }, 50 );
}

function exec_reload_images() {
	// change title
	document.title = "(" + getpage() + "/" + maxpage + ")";

	// set bookmark
	setbookmark();

	// set pageslider's min base on page
	if (isEvenPage()) {
		$('#pageslider').slider('option', 'min', 0);
	}
	else {
		$('#pageslider').slider('option', 'min', 1);
	}

	// set the page to make slider call changes and set the appropriate page
	$('#pageslider').slider('value', getpage());

	// remove image first then add, instead of changing image source ( otherwise image resize won't work)
	$('#ileft').remove();
	$('#ibar').remove();
	$('#iright').remove();

	// set icontainer height
	if (isNormalHeight()) {
		$('#icontainer').addClass('icontainer-normal_height');
	}
	else {
		$('#icontainer').removeClass('icontainer-normal_height');
	}

	// add left page
	if (isSinglePageMode()) {
		//** single page mode **//
		$('<img />').attr('id','ileft').appendTo('#icontainer');
		$('#ileft').css('display','none');
	}
	else {
		//** dual page mode **//
		if (isEasternBook()) {
			$('<img />').attr('id','ileft').attr("src", "/cbz/" + bookcode + "/" + (getpage() + 1) ).appendTo('#icontainer');
		}
		else {
			$('<img />').attr('id','ileft').attr("src", "/cbz/" + bookcode + "/" + getpage() ).appendTo('#icontainer');
		}
	}
	// set the left image height
	if (isNormalHeight()) $('#ileft').addClass('normal_height');

	// black bar mode
	if (isBlackBared()) {
		// with black bar
		$('<div></div>').attr('id','ibar').css('display','inline-block').appendTo('#icontainer');
	}
	else {
		// without black bar
		$('<div></div>').attr('id','ibar').css('display','none').appendTo('#icontainer');
	}

	// add right image
	if (isEasternBook()) {
		$('<img />').attr('id','iright').attr("src", "/cbz/" + bookcode + "/" + getpage() ).appendTo('#icontainer');
	}
	else {
		$('<img />').attr('id','iright').attr("src", "/cbz/" + bookcode + "/" + (getpage() + 1) ).appendTo('#icontainer');
	}
	// set the right image height
	if (isNormalHeight()) {
		$('#iright').addClass('normal_height');
	}
	else {
		$('#iright').addClass('full_height');
	}

	/*
	// adjust image dimention to compesate the single or dual page mode
	if (isSinglePageMode()) {
		// single page
		$('#iright').css('width','100%');
		$('#iright').css('height','100%');
	}

	// adjust image width to compensate the bar
	if (isBlackBared()) {
		$('#ileft').css('width','49%');
		$('#iright').css('width','49%');
	}
	*/
}

function isEasternBook() {
	return ( $('#readdirection :radio:checked').attr('id') == 'readtoleft' ) ? true : false;
}

function isNormalHeight() {
	return ( $('#itemsheight :radio:checked').attr('id') == 'normalheight' ) ? true : false;
}

function isEvenPage() {
	return ( $('#primarypage :radio:checked').attr('id') == 'pageeven' ) ? true : false;
}

function isOddPage() {
	return ( $('#primarypage :radio:checked').attr('id') == 'pageodd' ) ? true : false;
}

function isSinglePageMode() {
	return ( $('#pagemode :radio:checked').attr('id') == 'singlepage' ) ? true : false;
}

function isBlackBared() {
	return ( $('#barmode :radio:checked').attr('id') == 'yesbar' ) ? true : false;
}

function disable_buttons() {
	// reset and disable black bar
	$('#nobar').click();
	$('#barmode').buttonset('disable');

	// disable page even / odd mode
	$("#primarypage").buttonset('disable');

	// disable read direction
	$("#readdirection").buttonset('disable');
}

function enable_buttons() {
	// enable black bar
	$('#barmode').buttonset('enable');

	// enable page even / odd mode
	$('#primarypage').buttonset('enable');

	// enable readdirection
	$('#readdirection').buttonset('enable');
}



// keyboard commands
document.onkeydown = function(e) {
	e = e || window.event;

	switch (e.keyCode) {
		case 39:
			// right key, next page
			goNextPages();
			break;
		case 32:
			// space key, next page
			goNextPages();
			break;
		case 37:
			// left key, previous page
			goPrevPages();
			break;
		case 49:
			// 1 key, previous page
			goPrevPages();
			break;
		case 27:
			// escape key
			goHomepage();
			// catch this key, stopping the use of escape key from other function/program
			return false;
			break;
		case 192:
			// ` key, show/hide menu
			if (($('#menu').css('display')) == 'none') {
				showmenu();
			}
			else {
				hidemenu();
			}
			break;
		case 13:
			// enter key, show/hide menu
			if (($('#menu').css('display')) == 'none') {
				showmenu();
			}
			else {
				hidemenu();
			}
			break;
		case 65:
			// a key, normal or full height image
			if (isNormalHeight()) {
				/* change to full height */
				$('#fullheight').click();
			}
			else {
				/* change to normal height */
				$('#normalheight').click();
			}
			break;
		case 83:
			// s key, single or double page mode
			if (isSinglePageMode()) {
				$('#doublepage').click();
			}
			else {
				$('#singlepage').click();
			}
			break;
		case 69:
			// e key, eastern or western book mode
			if (isSinglePageMode()) break;

			if (isEasternBook()) {
				$('#readtoright').click();
			}
			else {
				$('#readtoleft').click();
			}
			break;
		case 66:
			// b key, with or without black bar
			if (isSinglePageMode()) break;

			if (isBlackBared()) {
				$('#nobar').click();
			}
			else {
				$('#yesbar').click();
			}
			break;
		case 86:
			// v key, even or odd page as primary page
			if (isSinglePageMode()) break;

			if (isEvenPage()) {
				$('#pageodd').click();
			}
			else {
				$('#pageeven').click();
			}
			break;
	}
	// catch/disable all other keys
	//return false;
}


function goHomepage() {
	var page = $.cookie('lastbrowse' + uport());

	if (page == undefined) {
		page = '/';
	}
	window.location.href = page;
}

function goNextPages() {
	if (getpage() < maxpage) {
		// set increment by 1 or 2 base on page mode
		var i = isSinglePageMode() ? 1 : 2;

		// change page by changing the slider, otherwise the navigation will have unpredictable or buggy behaviour
		$('#pageslider').slider('value', getpage() + i );
	}
}

function goPrevPages() {
	if (getpage() > 1) {
		// set increment by 1 or 2 base on page mode
		var i = isSinglePageMode() ? 1 : 2;

		// change page by changing the slider, otherwise the navigation will have unpredictable or buggy behaviour
		$('#pageslider').slider('value', getpage() - i );
	}
}

function showmenu() {
	$('#menu').css('display','block');
}

function hidemenu() {
	$('#menu').css('display','none');
}

// function to preload images
function preload(arrayOfImages) {
	// remove old element
	$('.pl_image').remove();

	// append new hidden image element
	$(arrayOfImages).each( function() {
		$('<img />').attr('src',this).appendTo('body').css('display','none').addClass('pl_image');
	});
}

function preload_images() {
	// precaching images for fast loading

	var	images = [
		"/cbz/" + bookcode + "/" + (getpage() + 2),
		"/cbz/" + bookcode + "/" + (getpage() + 3)
	];

	preload(images);
}

// set the bookmark
function setbookmark() {
	$.ajax({
		url: "/setbookmark/" + bookcode + "/" + getpage(),
		beforeSend: function ( xhr ) {
			xhr.overrideMimeType("text/plain; charset=x-user-defined");
		}
	}).done(function ( data ) {
		if( 1==2 && console && console.log ) {
			console.log("Sample of data:", data);
		}
	});
}

