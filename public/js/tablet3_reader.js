/*!
License: refer to LICENSE file
 */


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


function readBook(bc, bp) {
	// bc, bookcode
	// bp, bookpage

	$.get('/listbooks', { bookcodes: bc }, function(jData) {
		$('#container').removeClass('hidden');

		for (var bc1 in jData) {
			book = jData[bc1];

			book.bookcode = bc1;
			book.lastpage = bp || book.page || 1;

			$('#booktitle').html('<div>' + book.title + '</div>');

			// set #pageslider max
			$('#pageslider').attr('max', book.pages);
			$('#pageslider').val(book.lastpage);

			// create gallery
			createGallery();

			// set location hash
			window.location.hash = 'book=' + book.bookcode + '&page=' + book.lastpage;

			// put the slider on correct page
			setSliderPage();

			// force trigger hashchange to load correct page
			window.dispatchEvent(new HashChangeEvent('hashchange'));

			break;
		}

	});
}


function updateDivCurrentInfo(page) {

	if (typeof page === 'number') {
		$('#pageCounter').html( gallery.pageIndex + '/' + book.pages );
	}
	$('#clock').html( date.toTimeString().slice(0,5) );
	// $('#battery').html( '&#128267;' + battery_level); // ??? !!!
}

function sliderValue(el, e) {
	var el = $(el);
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
function destroyGallery() {
	gallery.destroy;
	$('#wrapper').empty();

	// remove listener
	$(window).unbind('hashchange');
	$(window).unbind('keydown');

	// clear hash
	window.location.hash = '';
}

// create the gallery
function createGallery() {
	setScreenSize();

	//document.addEventListener('touchmove', function (e) { e.preventDefault(); }, false);

	// global
	window.imageQueue = [];

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
				img: "/cbz/" + book.bookcode + "/" + (book.pages - i + 1),
				page: book.pages - i + 1
			} );
		}
		else {
			// western book
			slides.push( {
				img: "/cbz/" + book.bookcode + "/" + i,
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
		el.innerHTML = i + 1;
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
		}
		gallery.masterPages[i].appendChild(el);
	}

	gallery.onFlip(function () {
		console.log('flip event!');
		$('#battery').html(112)
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
				el.removeAttribute('src');
				// el.src = '';
				// el.src = slides[upcoming].img;
			}
		}

		// get current page
		var pg = gallery.pageIndex;
		if (isEasternBook()) {
			pg = book.pages - gallery.pageIndex;
		}

		// update div current info
		updateDivCurrentInfo(pg);

		// change title according to page
		document.title = "(" + pg + "/" + book.pages + ")";

		// set the page hash
		window.location.hash = fullhash(pg);
		
		setBookmark(book.bookcode, pg);
		setSliderPage();
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
		updateDivCurrentInfo(pg);
	});

	gallery.onMoveIn(function () {
		console.log('movein');
		var className = gallery.masterPages[gallery.currentMasterPage].className;
		/(^|\s)swipeview-active(\s|$)/.test(className) || (gallery.masterPages[gallery.currentMasterPage].className = !className ? 'swipeview-active' : className + ' swipeview-active');
	});
	// end of gallery code


	// now add listener

	// hash change
	$(window).bind('hashchange', function() {
		if (getpage() < 1) {
			window.location.replace( '#' + fullhash( 1 ) );
		}
		else if (getpage() > book.pages) {
			window.location.hash = fullhash( book.pages );
		}

		// launch a moment later, to go around loading issue
		window.setTimeout( function(e) { goToPage(getpage()); }, 50);
	});

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
				break;
			case 13:
				// enter key, show/hide menu
				togglemenu();
				break;
		}
	});
}

// set the bookmark
function setBookmark(bookcode, page) {
	var page = getpage();

	if (book.lastpage == page || page < 1 || page > book.pages) return false;

	$.ajax({
		url: "/setbookmark/" + bookcode + "/" + page,
		beforeSend: function ( xhr ) {
		xhr.overrideMimeType("text/plain; charset=x-user-defined");
	}
	}).done(function ( data ) {
		if( 1==2 && console && console.log ) {
			console.log("Sample of data:", data);
		}
	});

	// update last rendered page
	book.lastpage = page;
}


function closeReader() {
	$('#container').addClass('hidden');

	destroyGallery();

	reload_books( $('#bookinfo').attr('bookcodes') );
}

function isEasternBook() {
	return ( $('#readdirection :radio:checked').attr('id') == 'readtoleft' ) ? true : false;
}

function loadImage() {
	var dat = window.imageQueue.shift();
	
	// double trigger, stop
	if (window.currentImage && window.currentImage.url === dat.url) return;

	window.currentImage = dat;

	var img = el = $('<img>');
	img.on('load', function() {
		// console.log('loaded image in background', this.dat)

		// change img src
		var el = $(this.dat.igal);
		el.find('img').attr('src', this.dat.url).removeClass('loading');
		el.find('div').removeClass('loading');
		el.css('visibility','visible');

		// do more if exists
		if (window.imageQueue && window.imageQueue.length > 0) {
			loadImage();
		}
		// all done, clear
		else {
			window.currentImage = false;
		}
	}.bind({
		dat: dat
	}));
	// exec
	// console.log('starting', dat)
	img.attr('src', dat.url);
}

// go to particular page
// in relative to book
// not relative to gallery, which u can find out by page - 1
function goToPage(page) {
	if (page < 1) return false;

	if (isEasternBook()) {
		gallery.goToPage(book.pages - page);
	}
	else {
		gallery.goToPage(page - 1);
	}


// new
	window.imageQueue = [];

	var i;
	if (isEasternBook()) {
		i = book.pages - page;
	}
	else {
		i = page - 1;
	}
	window.imageQueue = [
		// current page
		{
			igal: '[data-page-index=' + i + ']',
			url: "/cbz/" + book.bookcode + "/" + page
		},
		// next page
		{
			igal: '[data-page-index=' + (i+1) + ']',
			url: "/cbz/" + book.bookcode + "/" + (page + 1)
		},
		// prev page
		{
			igal: '[data-page-index=' + (i-1) + ']',
			url: "/cbz/" + book.bookcode + "/" + (page - 1)
		},
	];

	// do first image
	loadImage();

// new end
}

// get the page from hash
function getpage() {
	var i = parseInt( getHashParams()['page'] );
	if (typeof i == "number" && ! isNaN(i) ) {
		return i;
	}

	return -1;
}


// set the slider displayed page
function setSliderPage() {
	$('#pageinput').val(getpage());
	$('#pageslider').val(getpage());
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

function toggleFullScreen(id) {
	var elem = document.getElementById(id);
	var btn = $('#gofullscreen'); // button for toggle full screen

	if (isFullScreen()) {
		btn.text('full screen');

		exitFullScreen();
	}
	else {
		btn.text('exit full screen');

		goFullScreen(id);
	}

	// refresh button text
	btn.button('refresh');
}
