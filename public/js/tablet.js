/*jshint es3: true */

// ########################################################################################
// #
// #      browse
// #
// ########################################################################################

function searchBoxOnKeyUp(e) {
	// will be a window.event if used onkeyup in attribute
	e = e || window.event;

	if (e.keyCode == 13) {
		// enter key, unfocus the searchbox
		$(e.originalTarget).blur();

		// search
		reload_leftmenu(false, e.originalTarget.value);
	}
}

// global search result list
function reload_leftmenu(topMenuElem, keyword) {
	if (!!topMenuElem) {
        // remove current top menu highlight, so no double highlight
		$('.btn-group > button').removeClass('active');
        // set new highlight
        topMenuElem = $(topMenuElem);
        topMenuElem.addClass('active');

        // remember last menu selection number
        var id = topMenuElem.attr('id');
        var num = id.replace('bc','');
        $.cookie(uport() + '.last_menu_selection_number', num, { path: '/' });
    }

    // load the api url
	var url;
	if (!!topMenuElem) {
        url = $(topMenuElem).attr('link');

	} else {
		url = $('.btn-group > button.active').attr('link');
	}
    
    if (typeof keyword === 'string') {
        // keyword specified, remember it
        if (get_topmenu_selection() === 'author') {
			// save author
			$.cookie(uport() + '.author', keyword);
		}
		else {
			// save normal keyword
			$.cookie(uport() + '.keyword', keyword);
		}
    }
    else {
        // if keyword is not specified, restore from cookie
		if (get_topmenu_selection() === 'author') {
			// load author
			keyword = $.cookie(uport() + '.author') || '';
		}
		else {
			// load normal keyword
			keyword = $.cookie(uport() + '.keyword') || '';
		}

        // set text in searchbox
        $('#searchbox').val(keyword);
	}

	// retrive data
	$.post(url, { keyword: keyword }, function(data) {
        // load data into iscroll (left menu)
		myScrollUL = data;
		// restart iscroll
		if (!!myScroll) myScroll.destroy();
		iScrollLoad(myScrollUL.length);
		myScroll.updateCache(0, myScrollUL.slice(0, 60));

		// does the book found, if not, select first item in scroll
		var selectFirst = true;

        // highlight last selected left menu
        var lastBookcodes = $.cookie(uport() + '.' + get_topmenu_selection() + '.lastBookcodes');
		for (var i=0; i<myScrollUL.length; i++) {
            var obj = myScrollUL[i];

			if (obj.bookcodes.toString() === lastBookcodes) {
				// show books
				var lastSelectOptions = $.cookie(uport() + '.lastSelectOptions');

				// highlight left menu
				$('li.irow[bookcodes="' + lastBookcodes + '"]').addClass('left-picked');

				reload_books(lastBookcodes, lastSelectOptions);

				selectFirst = false;
				break;
			}
		}

        // last selected title don't exist (for highlight), select first available title
		if (selectFirst) {
            var firstRow;
			var rows = document.getElementsByClassName("irow");
			if (rows && rows.length > 0) {
				firstRow = rows[0];
			}
			
			if (firstRow) {
				// found first row
				var bookCodes = firstRow.getAttribute("bookcodes");
				var options = firstRow.getAttribute("options");

				reload_books(bookCodes, options);
			}
			else {
				// no row found, reset state to blank
				reload_books();
			}
		}
	});
}

// load books from the bookcodes
function reload_books( bookcodes, options ) {
	if (!!!bookcodes) {
		$('#bookinfo').empty();
		$('#books').empty();
		return false;
	}

	$.get('/api/books/info', { bookcodes: bookcodes, options: options }, function(jData) {
		var el; // html element
		var bookcode; // str
		var book;
		var menuSelect = get_topmenu_selection();

		// show book title and author
		var funcShowAuthor = function(event) {
			reload_leftmenu($('#bc5'), event.data.author);
		};
		el = $('#bookinfo');
		el.empty();
		el.attr('bookcodes', bookcodes); // remember requested bookcodes
		for (bookcode in jData) {
			book = jData[bookcode];

			// show author first, otherwise long title might block author
			var author = $('<div>');
			author.text(book.author);
			author.on('click', {author: book.author} ,funcShowAuthor);
			el.append(author);

			// show book names if it is not auther listing
			if (menuSelect !== 'author') {
				var title = $('<div>');
				title.text(book.title);
				el.append(title);
			}
			break;
		}

		// list books
		var funcReadBook = function(event) {
			readBook(event.data.bookcode, event.data.bookpage);
		};
		el = $('#books');
		el.empty();
		for (bookcode in jData) {
			book = jData[bookcode];

			var li = $('<li>');
			li.addClass('book');

			var a = $('<a>');
			var apage = 1;
			if (!!book.page) apage = book.page;
			a.attr('href', '#book=' + bookcode + '&page=' + apage);
			a.on('click', { bookcode: bookcode, bookpage: apage }, funcReadBook);

			var img = $('<img>');
			img.attr('src', '/api/book/thumb/' + bookcode);
			img.attr('alt', 'Loading...');
			a.append(img);

			var span = $('<span>');

			// show book names if author book listing
			if (menuSelect === 'author') {
				span.text(book.title);
			} else {
				span.text(book.sname);
			}
		
			// set page progress
			var page  = book.page || 0;
			var pages = book.pages;
			var pc    = Math.round(page / pages * 100); // percentage read
			var pc2   = pc === 0 ? 0 : pc + 1; // if never read, then make it all 0
			span.addClass('title');
			span.css('background', 'linear-gradient(to right, rgba(51,204,102,1) ' + pc + '%,rgba(234,234,234,1) ' + pc2 + '%)');
			a.append(span);

			// show total pages
			var spanPages = $('<span>');
			spanPages.addClass('badge badge-info bookpages');
			spanPages.text(book.pages);
			a.append(spanPages);

			li.append(a);
			el.append(li);
		}
	});

}

function get_topmenu_selection() {
	var id = $('#bcs > button.active').attr('id');

	var n;
	if (id) {
		n = parseInt(id.replace('bc',''), 10);
	}

	if (n === 1) return 'all';
	if (n === 2) return 'new';
	if (n === 3) return 'reading';
	if (n === 4) return 'finished';
	if (n === 5) return 'author';

	return 'all';
}

// ########################################################################################
// #
// #      reader
// #
// ########################################################################################

// last time the toggleMenu is called
var lastToggleMenu = (new Date()).getTime();

// initialize book object
var book;

// set gallery global variable so it can be accessed outside
var gallery;

// set date
var date = new Date();

// set battery
var battery_level = '-1';

// how long it takes to trigger actions in ms
var onFlipActionDelay = 1000;


function readBook(bookcode, bookpage) {
	// destroy exiting gallery already exists
	destroyGallery(false);

	// set screen size so if the image is resized, server remember the screen size
	setScreenSize();

	$.get('/api/books/info', { bookcodes: bookcode }, function(jData) {
		$('#container').removeClass('hidden');

		book = jData[bookcode];

		book.bookcode = bookcode;
		book.lastpage = bookpage || book.page || 1;

		$('#booktitle').html('<div>' + book.title + '</div>');

		// set #pageslider max
		$('#pageslider').attr('max', book.pages);
		$('#pageslider').val(book.lastpage);

		// set location hash if not set or diff
		var hstr = '#book=' + book.bookcode + '&page=' + book.lastpage;
		if (window.location.hash !== hstr) window.location.hash = hstr;

		// create gallery
		createGallery(bookpage);

		// force trigger hashchange to load correct page
		// window.dispatchEvent(new HashChangeEvent('hashchange'));
	});
}

function updateReaderFooter(page) {
	if (typeof page !== 'number') {
		page = -1;
	}
	var pages = -1;
	if (book && book.pages) {
		pages = book.pages;
	}

	$('#pageCounter').html( page + '/' + pages );

	$('#clock').html( date.toTimeString().slice(0,5) );

	getBatteryLevel().then(function(batteryPercentText) {
		$('#battery').html( '&#128267;' + batteryPercentText);
	});
}

function sliderValue(el, e) {
	el = $(el);
	var min = Number(el.attr('min'));
	var max = Number(el.attr('max'));
	var t;
	if (e.originalEvent.touches) {
		t = e.originalEvent.touches[0];
	}
	// else { 
	// 	t = e.originalEvent;
	// }
	var w = Number(el.width());
	var x = w / max;
	var l = el.position().left;

	// approximate value on the slider position
	var i = Math.ceil((t.pageX - l)/x );

	if (i < min) {
		i = min;
	}
	else if (i > max) {
		i = max;
	}

	return i;
}


// destroy and remove the gallery
function destroyGallery(resetHash) {
	if (gallery) gallery.destroy();
	$('#wrapper').empty();

	// remove listener
	$(window).unbind('keydown');

	if (resetHash === false) return;

	// clear hash
	window.location.hash = '';
}

// create the gallery
function createGallery(goPage) {
	//document.addEventListener('touchmove', function (e) { e.preventDefault(); }, false);

	// initialize gallery
	var el,
		i,
		page;
		//dots = document.querySelectorAll('.thumbnails ul li');

	// initialize pages
	var slides = [];
	for (i=1; i<=book.pages; i++) {

		if (isEasternBook()) {
			// eastern book
			slides.push( {
				img: "/api/book/page/" + book.bookcode + "/" + (book.pages - i + 1),
				page: book.pages - i + 1
			} );
		}
		else {
			// western book
			slides.push( {
				img: "/api/book/page/" + book.bookcode + "/" + i,
				page: i
			} );
		}
	}

	gallery = new SwipeView('#wrapper', { numberOfPages: slides.length, loop: false, zoom: true });

	// Load initial data
	for (i=0; i<3; i++) {
		page = i==0 ? slides.length-1 : i-1;

		el = document.createElement('div');
		el.id = 'swipeview-div-' + i;
		el.className = 'loading';
		// el.innerHTML = i + 1;
		gallery.masterPages[i].appendChild(el);

		el = document.createElement('img');
		el.id = 'swipeview-img-' + i;
		el.className = 'loading';
		el.removeAttribute('src');
		// el.src = '';
		// el.src = slides[page].img;
		el.onload = function () {
			this.className = '';
			this.previousSibling.className = '';
		};
		gallery.masterPages[i].appendChild(el);
	}
	// stagger loading image to reduce load
	staggerImages(goPage);

	gallery.onFlip(function () {
		console.log('flip event!');
		// global
		if (!window.timerOnFlipSlide) window.window.timerOnFlipSlide = {};

		var el,
			upcoming,
			i;

		for (i=0; i<3; i++) {
			upcoming = gallery.masterPages[i].dataset.upcomingPageIndex;

			if (upcoming != gallery.masterPages[i].dataset.pageIndex) {
				el = gallery.masterPages[i].querySelector('div');
				el.className = 'loading';
				el.innerHTML = slides[upcoming].page;

				el = gallery.masterPages[i].querySelector('img');
				el.className = 'loading';

				// called by staggerImages
				if (window.stopOnFlipImg) {
					el.removeAttribute('src');
				}
				// normal flip
				else {
					// if (window.timerOnFlipSlide[i]) {
					// 	console.log('stop load image!', i)
					// 	clearTimeout(window.timerOnFlipSlide[i]);
					// 	window.timerOnFlipSlide[i] = false;
					// }

					// window.timerOnFlipSlide[i] = setTimeout(function() {
					// 	console.log('load image!', this.src)
					// 	this.el.src = this.src;
					// }.bind({
					// 	el: el,
					// 	src: slides[upcoming].img
					// }), onFlipActionDelay);

					el.src = slides[upcoming].img;
				}
			}
			// else {
			// 	if (window.timerOnFlipSlide[i]) {
			// 		console.log('stop load image!!!', i)
			// 		clearTimeout(window.timerOnFlipSlide[i]);
			// 		window.timerOnFlipSlide[i] = false;
			// 	}
			// }
		}
		// reset
		window.stopOnFlipImg = false;

		// get current page
		var pg = gallery.pageIndex;
		if (isEasternBook()) {
			pg = book.pages - gallery.pageIndex;
		}

		// update div current info
		updateReaderFooter(pg);

		// change title according to page
		document.title = "(" + pg + "/" + book.pages + ")";

		// set the page hash, make sure no new page history
		window.location.replace('#book=' + book.bookcode + '&page=' + pg);

		// set bookmark only if stopped at page
		if (window.timerOnFlipSlide.bookmark) {
			clearTimeout(window.timerOnFlipSlide.bookmark);
			window.timerOnFlipSlide.bookmark = false;
		}
		window.timerOnFlipSlide.bookmark = setTimeout(function() {
			setBookmark(this.bookcode, this.pg);
		}.bind({
			bookcode: book.bookcode,
			pg: pg
		}), onFlipActionDelay);

		// set the slider displayed page
		$('#pageinput').val(pg);
		$('#pageslider').val(pg);
	});

	gallery.onMoveOut(function () {
		console.log('moveout');
		gallery.masterPages[gallery.currentMasterPage].className = gallery.masterPages[gallery.currentMasterPage].className.replace(/(^|\s)swipeview-active(\s|$)/, '');

		// get current page
		var pg = gallery.pageIndex;
		if (isEasternBook()) {
			pg = book.pages - gallery.pageIndex;
		}

		var el = gallery.masterPages[gallery.currentMasterPage].querySelector('div');
		el.innerHTML = pg;
		el.className += 'loading';

		// update current info
		updateReaderFooter(pg);
	});

	gallery.onMoveIn(function () {
		console.log('movein');
		var className = gallery.masterPages[gallery.currentMasterPage].className;
		/(^|\s)swipeview-active(\s|$)/.test(className) || (gallery.masterPages[gallery.currentMasterPage].className = !className ? 'swipeview-active' : className + ' swipeview-active');
	});
	// end of gallery code

	// go to page if specified
	if (goPage) {
		// launch a moment later, to go around loading issue
		window.setTimeout( function(e) { goToPage(goPage); }, 300);
	}

	// // keyboard commands
	$(window).bind('keydown', function h_kd(e) {
		e = e || window.event;

		switch (e.keyCode) {
			case 37:
				// left button, previous page
				goToPage( getpage() - 1 );
				break;
			case 39:
				// right button, next page
				goToPage( getpage() + 1 );
				break;
			case 27:
				// escape button, go back to browse
				closeReader();
				return false;
			case 13:
				// enter key, show/hide menu
				togglemenu();
				break;
		}
	});
}

// set the bookmark
function setBookmark(bookcode, page) {
	page = getpage();

	if (book.lastpage == page || page < 1 || page > book.pages) return false;

	$.post('/api/book/bookmark', { bookcode: bookcode, page: page }, function(data) {
		console.log(data);
	});

	// update last rendered page
	book.lastpage = page;
}


function closeReader() {
	$('#container').addClass('hidden');

	$('#menu').removeClass("hidden");
	$('#window').removeClass("hidden");

	destroyGallery();

	document.title = "Kamishibai";

	reload_books( $('#bookinfo').attr('bookcodes') );
}

function isEasternBook() {
	return ( $('#readdirection :radio:checked').attr('id') == 'readtoleft' ) ? true : false;
}

// go to particular page
// in relative to book
// not relative to gallery, which u can find out by page - 1
function goToPage(page) {
	page = Number(page);
	console.log('going to page', page);
	if (page < 1) return false;
	if (isNaN(page)) {
		page = 1;
	}

	if (isEasternBook()) {
		gallery.goToPage(book.pages - page);
	}
	else {
		gallery.goToPage(page - 1);
	}

	staggerImages(page);
}

function staggerImages(page) {
	var i;
	if (isEasternBook()) {
		i = book.pages - page;
	}
	else {
		i = page - 1;
	}

	// global
	window.stopOnFlipImg = true;
	window.imageQueue = [
		// current page
		{
			igal: '[data-page-index=' + i + ']',
			url: "/api/book/page/" + book.bookcode + "/" + page
		},
		// next page
		{
			igal: '[data-page-index=' + (i+1) + ']',
			url: "/api/book/page/" + book.bookcode + "/" + (page + 1)
		},
		// prev page
		{
			igal: '[data-page-index=' + (i-1) + ']',
			url: "/api/book/page/" + book.bookcode + "/" + (page - 1)
		}
	];

	// do first image
	loadImage();
}

function loadImage() {
	var dat = window.imageQueue.shift();
	
	// double trigger, stop
	if (window.currentImage && window.currentImage.url === dat.url) return;

	window.currentImage = dat;

	var img = $('<img>');
	img.on('load', function() {
		// change img src
		var el = $(this.dat.igal);
		el.find('img').attr('src', this.dat.url).removeClass('loading');
		el.find('div').removeClass('loading');
		el.css('visibility','visible');

		// do more if exists
		if (window.imageQueue && window.imageQueue.length > 0) {
			loadImage();
		}
		else {
			// all done, clear
			window.currentImage = false;
		}
	}.bind({
		dat: dat
	}));

	// exec
	if (typeof dat.url === "string") {
		img.attr('src', dat.url.replace("null","1"));
	} else {
		console.error("dat.url not a string");
	}
}

// get the page from hash
function getpage() {
	var i = parseInt(getHashParams("page"), 10);
	if (typeof i === "number" && ! isNaN(i) ) {
		return i;
	}

	return -1;
}

// toggle menu
function togglemenu() {
	if ($('#readermenu').hasClass('showtop')) {
		hidemenu();
	}
	else {
		showmenu();
	}

	var t = new Date();
	lastToggleMenu = t.getTime();
}

// show menu
function showmenu() {
	// show the menu
	$('#booktitle').addClass('showtop');
	$('#readermenu').addClass('showtop');
}

function hidemenu() {
	// set header & footer hidden
	$('#booktitle').removeClass('showtop');
	$('#readermenu').removeClass('showtop');
}

// show/hide menu when touch the page
function hasMoved(b,e) {
	// move threshold
	var mt = 5;

	// shortcut for getting object
	//var b = begin.originalEvent.changedTouches[0];
	//var e = end.originalEvent.changedTouches[0];

	// **hack**
	// changed to array form because iOS+jQuery dont handle originalEvent and changedTouches correctly
	// it doesn't store the last_touchstart correctly (it holds current one instead, so touchstart and touchend always ended up same value)
	if (Math.abs(b[0] - e[0]) > mt || Math.abs(b[1] - e[1]) > mt) {
		//console.log('moved');
		return true;
	}
	else {
		//console.log('not moved');
		return false;
	}
}

// ########################################################################################
// #
// #      main
// #
// ########################################################################################

// global variables
var hasTouch = 'ontouchstart' in window; //find out if device is touch device or not

var fullScreenAvailable = document.fullscreenEnabled || 
                            document.mozFullscreenEnabled ||
                            document.webkitFullscreenEnabled ||
                            document.msFullscreenEnabled;

// for iscroller
document.addEventListener('touchmove', function (e) { e.preventDefault(); }, false);

/*
	**** NOTE ****
	Seems like ios uses the noclick delay to detect div drag, so if this is enabled, the div navi would not work. need to come up alternative method.
*/
// disable onclick delay on ipad/ios, it has dodgy handing on click event
if ((/iphone|ipod|ipad.*os 5/gi).test(navigator.appVersion)) {
	//new NoClickDelay(document.body);
}

// page init
function onload() {
	/*
	*  Browse section
	*/

	// load the text localization
	reload_locale();

	// re-select the remembered menu selection
	var i = $.cookie(uport() + '.last_menu_selection_number') || 1;
	$('#bc' + i)
    .button('toggle')
    .trigger('click');

	// swipe event for the browse page
	$(window).bind('scroll', function() {
		$('#scroll-pos').text(window.pageYOffset);
	});
	$('#books').bind('onscroll', function() {
		$('#scroll-pos').text(window.pageYOffset);
	});

	if (getHashParams("book")) {
		// load book if already specified in hash

		var p = getHashParams("page") || 1;

		readBook( getHashParams("book"), p );
	}
	else {
		$('#menu').removeClass("hidden");
		$('#window').removeClass("hidden");
	}

	/*
	 *  Reader section
	 */

	// disable other other tuochmove events from propagating causing issuing
	// document.addEventListener('touchmove', function (e) { e.preventDefault(); }, false);

	// show/hide menu
	if (hasTouch) {
		$('#wrapper').on('click', function(e) {
			e.stopPropagation();
			togglemenu();
		});
	}
	else {
		// prevent swipe triggering menu when using mouse
		$('#wrapper').on('mousedown', function(e) {
			window.wrapperMouseLastPos = {
				x: e.originalEvent.pageX,
				y: e.originalEvent.pageY
			};
		});
		$('#wrapper').on('mouseup', function(e) {
			var x = e.originalEvent.pageX;
			var y = e.originalEvent.pageY;

			// moved, so no menu
			if (Math.abs(window.wrapperMouseLastPos.x - x) > 10) return;
			if (Math.abs(window.wrapperMouseLastPos.y - y) > 10) return;

			togglemenu();
		});
	}
	
	// change page when slider is moved
	$('#pageslider').on('change', function() {
		goToPage( $(this).val() );

	}).on('input', function() {
		$('#pageinput').val( $(this).val() );

	}).on('touchstart', function(e) {

		// change page when slider is moved (touch)
		var i = sliderValue(this, e);

		$('#pageinput').val( i );
		$(this).val(i);

	}).on('touchmove', function(e) {
		// console.log('slider move');
		var i = sliderValue(this, e);
		
		$('#pageinput').val( i );
		$(this).val(i);

	}).on('touchend', function(e) {
		// goToPage( $(this).val() );
	});

	// change read direction when button is touched
	$('#readdirection').change(function(e) {
		destroyGallery();
		createGallery();
		// force trigger hashchange on load
		window.dispatchEvent(new HashChangeEvent('hashchange'));
	});

	updateReaderFooter();
	window.setInterval( function() {
		updateReaderFooter(p);
	}, 1000 * 60);

	// show full screen button if device supports it
	if (fullScreenAvailable) {
		$('#full-screen-btn').removeClass('hidden');
	}

	// hash change
	$(window).bind('hashchange', function(e) {
		var ev = e.originalEvent;
		var fromTablet = false;
		var toTablet = false;
		if (ev.oldURL.indexOf('book=') > -1) {
			fromTablet = true;
		}
		if (ev.newURL.indexOf('book=') > -1) {
			toTablet = true;
		}

		// is in reader mode
		if (typeof getHashParams('book') !== 'undefined') {
			var topage = getpage();

			if (topage < 1) {
				topage = 1;
			}
			else if (book && topage > book.pages) {
				topage = book.pages;
			}

			// replace the history
			window.location.replace( '#' + fullhash( topage ) );
		}

		// anything else, if in/out of tablet page, reload the page
		if ((fromTablet ^ toTablet) === 1) {
			window.location.reload();
		}
	});

}

var myScroll;
var myScrollUL = []; // store array of ul data for #iscroller-ul to use

function iScrollLoad(maxLength) {
	if (!!!maxLength) maxLength = 0;
	
	$('.irow').text('').prop('onclick', null).off('click');
	
	// scroll to last Y position
	var lastScrollY = parseInt($.cookie(uport() + '.' + get_topmenu_selection() + '.lastScrollY'), 10);
	if (isNaN(lastScrollY)) {
		lastScrollY = 0;
	}

	myScroll = new IScroll('#iwrapper', {
		mouseWheel: true,
		infiniteElements: '#iscroller .irow',
		infiniteLimit: maxLength,
		dataset: iScrollRequestData,
		dataFiller: iScrollUpdateContent,
		cacheSize: 60,
		startY: lastScrollY,
		scrollEnd: function(e, x) {
            // not working, not called, need more investigate if it even exists
			console.log(111, e, 222, x);
		}
	});

	// make sure left are rendered with new y position
	setTimeout(function() {
		myScroll.refresh();
	}, 500);
}

function iScrollRequestData(start, count) {
	var data = myScrollUL.slice(start, start+count);
	
	// skip if not ready
	if (!!!myScroll) return;

	myScroll.updateCache(start, data);
}

function iScrollUpdateContent(el, data) {
	// reset
	el.removeAttribute("author");
	el.removeAttribute("title");
	el.removeAttribute("bookcodes");
	el.removeAttribute("options");
	el.onclick = undefined;

	if (!!!data) return;

	el.setAttribute("bookcodes", data.bookcodes);

	switch (get_topmenu_selection()) {
		case 'all':
		case 'new':
		case 'reading':
		case 'finished':
			el.innerText = data.title;
			break;
		case 'author':
			el.innerText = data.author;
			el.setAttribute("options", "sortbyauthor");
			break;
	}


	el.onclick = function(event) {
		var bookcodes = this.getAttribute("bookcodes");
		var options = this.getAttribute("options");

		// remember last selected book, base on menu selected
		$.cookie(uport() + '.' + get_topmenu_selection() + '.lastBookcodes', bookcodes, { path: '/' });

		// remember last scroll position, base on menu selected
		$.cookie(uport() + '.' + get_topmenu_selection() + '.lastScrollY', myScroll.y, { path: '/' });

		// remember last select options
		$.cookie(uport() + '.lastSelectOptions', options, { path: '/' });

		// change colour to make it easier to see
		$('.left-picked').removeClass('left-picked');
		setTimeout(function() {
			$(this.el).addClass('left-picked');
		}.bind({el: this}), 100);

		// load books and details
		reload_books( bookcodes, options );
	};
}
