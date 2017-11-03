/*!
License: refer to LICENSE file
 */

// function to format the hash to object
// example: #book=abc.zip&page=7 -> $['book']='abc.zip', $['page']=7
function getHashParams() {
    var hashParams = {};
    var e,
        a = /\+/g,  // Regex for replacing addition symbol with a space
        r = /([^&;=]+)=?([^&;]*)/g,
        // d = function (s) { return decodeURIComponent(s.replace(a, " ")); },
        d = function (s) { return decodeURIComponent(s); },
        q = window.location.hash.substring(1);

    while (e = r.exec(q))
       hashParams[d(e[1])] = d(e[2]);

    return hashParams;
}

// return fully formatted hash
function fullhash(page) {
	return 'book=' + getHashParams()['book'] + '&page=' + page;
}

// a queue that will make the browser run more responsively
// renamed $.queue to $.jobqueue, because of name conflict with scrollTo jquery plug-in
$.jobqueue = {
    _timer: null,
    _queue: [],
    add: function(fn, context, time) {
        var setTimer = function(time) {
            $.jobqueue._timer = setTimeout(function() {
                time = $.jobqueue.add();
                if ($.jobqueue._queue.length) {
                    setTimer(time);
                }
            }, time || 2);
        }

        if (fn) {
            $.jobqueue._queue.push([fn, context, time]);
            if ($.jobqueue._queue.length == 1) {
                setTimer(time);
            }
            return;
        }

        var next = $.jobqueue._queue.shift();
        if (!next) {
            return 0;
        }
        next[0].call(next[1] || window);
        return next[2];
    },
    clear: function() {
        clearTimeout($.jobqueue._timer);
        $.jobqueue._queue = [];
    }
};

function reload_locale() {
    // load the text localization for corresponding language i18n
    var opts = { pathPrefix: "/lang" };
    $("[data-localize]").localize("k", opts);
}

// set screen resolution on the session
function setScreenSize() {
    $.post('/screen', { width: window.innerWidth, height: window.innerHeight }, function(json) {
        if (json.outcome == 'success') {
            // do something with the knowledge possibly?
        } else {
            alert('Unable to let server know what the screen resolution is!');
        }
    },'json');
}

function uport() {
    // get the url port
    var port = window.location.port || '80';
    return port;
}


/*
  full screen functions
*/
function goFullScreen(i) {
    var elem;

    // if out what i is
    if (typeof i == 'object' || i instanceof Object) {
        // i is a DOM element
        elem = i;
    }
    else if (typeof i == 'string' || i instanceof String) {
        // i is an ID of DOM element
        elem = document.getElementById(i);
    }
    else {
        alert('goFullScreen(): unknown i');
    }

    // go full screen
    if (elem.mozRequestFullScreen) {
        elem.mozRequestFullScreen();
    }
    else if (elem.webkitRequestFullScreen) {
        elem.webkitRequestFullScreen();
    }
    else {
        alert('cannot go full screen');
    }
}

function exitFullScreen() {
    if (document.mozCancelFullScreen) {
        document.mozCancelFullScreen();
    }
    else if (document.webkitCancelFullScreen) {
        document.webkitCancelFullScreen();
    }
    else {
        alert('cannot exit full screen');
    }
}

function toggleFullScreen(id) {
    if (isFullScreen()) {
        exitFullScreen();
    }
    else {
        goFullScreen(id);
    }
}

function isFullScreen() {
    if (typeof document.mozFullScreen != 'undefined') {
        return document.mozFullScreen;
    }
    else if (typeof document.webkitIsFullScreen != 'undefined') {
        return document.webkitIsFullScreen;
    }
    else if (screen.width == window.innerWidth && screen.height == window.innerHeight) {
        return true;
    }
    else {
        return false;
    }
}

function isImageCached(src) {
    var image = new Image();
    image.src = src;

    return image.complete;
}

function updateBatteryLevel() {
    if (navigator.battery) {
        // firefox support
        battery_level = Math.floor(navigator.battery.level * 100) + '%';
    }
    else if (navigator.getBattery()) {
        // chrome support
        navigator.getBattery().then(function(battery) { battery_level =  Math.floor(battery.level * 100) + '%' });
    }
}
