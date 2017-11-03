/*!
License: refer to LICENSE file
 */

 // global variables
var hasTouch = 'ontouchstart' in window; //find out if device is touch device or not

// for saving cycle when typing keyword, delay search instead send immediately
var timerKeywordChange = 0;



// page init
$(function(e) {
	/*
	 *  Browse section
	 */

	// load the text localization
	reload_locale();

	/*
		**** NOTE ****
		Seems like ios uses the noclick delay to detect div drag, so if this is enabled, the div navi would not work. need to come up alternative method.
	*/
	// disable onclick delay on ipad/ios, it has dodgy handing on click event
	if ((/iphone|ipod|ipad.*os 5/gi).test(navigator.appVersion)) {
		//new NoClickDelay(document.body);
	}

	// set cookies
	// load the book search query
	var sb = $('#searchbox');
	if ($.cookie(uport() + '.keyword') != undefined) {
		sb.val( $.cookie(uport() + '.keyword') );
	}


	// re-select the remembered menu selection
	var i = $.cookie(uport() + '.last_menu_selection_number') || 1;

	// select menu selection
	$('#bc' + i).button('toggle');

	var bcs = $('#bcs');
	if (i == 5) {
		// author selected, load author

		sb.val( bcs.attr('author') || $.cookie(uport() + '.author') || '' );
	}
	else {
		// non author selected, load normal keyword

		sb.val( bcs.attr('keyword') || $.cookie(uport() + '.keyword') || '' );
	}


	// swipe event for the browse page
	$(window).bind('scroll', function() {
		$('#scroll-pos').text(window.pageYOffset);
	});
	$('#books').bind('onscroll', function() {
		$('#scroll-pos').text(window.pageYOffset);
	});



	// #searchbox event
	$("#searchbox").on('change', function(e) {

		// reload the list with keyword matches
		prepare_lists();

	}).on('keydown', function(e) {

		// save cycles, stop the timer to send query when key is pressed
		clearTimeout( timerKeywordChange );

	}).on('keyup', function(e) {
		e = e || window.event;

		if (e.keyCode == 13) {
			// enter key, unfocus the searchbox
			$("#searchbox").blur();
			return true;
		}

		// save cycles, only sent query when search is truly finished typing
		timerKeywordChange = setTimeout( function() {
			prepare_lists();

		}, 1200);
	});



	// run if book choice is selected, load with delay for the button group DOM to catch up
	$('.btn-group > button').on('click', function(e) {

		var sb  = $('#searchbox');
		var bcs = $('#bcs');
		// get menu selection
		var i   = $(this).attr('id').replace('bc', '');


		if (i == 5) {
			// author selected, load author

			sb.val( bcs.attr('author') || $.cookie(uport() + '.author') || '' );
		}
		else {
			// non author selected, load normal keyword

			sb.val( bcs.attr('keyword') || $.cookie(uport() + '.keyword') || '' );
		}

		// remember last menu selection number
		$.cookie(uport() + '.last_menu_selection_number', i, { path: '/' });


		// change button high light
		$('.btn-group > button').removeClass('active');
		$(this).addClass('active');

		// save cycles if search text isnt changed
		// if ( sb.val() === $.cookie(uport() + '.keyword') || sb.val() === $.cookie(uport() + '.author') ) {
		// 	return false;
		// }

		prepare_lists();
	});


	if (getHashParams().book) {
		// load book if already specified in hash

		var p = getHashParams().page || 1;

		readBook( getHashParams().book, p );
	}
	else {
		// reload leftbox
		// prepare_lists( get_menu_url() );
	}





	/*
	 *  Reader section
	 */

	// disable other other tuochmove events from propagating causing issuing
	// document.addEventListener('touchmove', function (e) { e.preventDefault(); }, false);


	// action when home button is pushed
	$('#closeReader').on('click', function(event, ui) {
		closeReader();
	});

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

	updateBatteryLevel();
	updateDivCurrentInfo();
	window.setInterval( function() {
		// update battery level
		updateBatteryLevel();

		// show clock
		updateDivCurrentInfo();
	}, 1000 * 60);


	// load full screen button if device supports it
	if (!(/iphone|ipod|ipad/gi).test(navigator.appVersion)) {
		$('#div-fs-btn').removeClass('hidden');
	};

});