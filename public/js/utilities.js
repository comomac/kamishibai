/*!
License: refer to LICENSE file
 */

// function to format the hash to object
// example: #book=abc.zip&page=7 -> $['book']='abc.zip', $['page']=7
function getHashParams(singleParam) {
    var hashParams = {};
    var e,
        a = /\+/g,  // Regex for replacing addition symbol with a space
        r = /([^&;=]+)=?([^&;]*)/g,
        // d = function (s) { return decodeURIComponent(s.replace(a, " ")); },
        d = function (s) { return decodeURIComponent(s); },
        q = window.location.hash.substring(1);

    while (e = r.exec(q))
       hashParams[d(e[1])] = d(e[2]);

    if (!!singleParam) {
        // return text
        return hashParams[singleParam];
    }

    // return object
    return hashParams;
}

// re-set fully formatted hash, replace history
function replace_full_hash(bookcode, page) {
    var hashes = ["book=" + bookcode + "&page=" + page];

    for (var k in getHashParams()) {
        if (k == "book") continue;
        if (k == "page") continue;

        hashes.push(k + "=" + getHashParams(k));
    }
	window.location.replace("#" + hashes.join("&"));
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
        };

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


function toggleFullScreen(id) {
    var doc = window.document;
    var docEl = doc.getElementById(id);
   
    var requestFullScreen = docEl.requestFullscreen || docEl.mozRequestFullScreen || docEl.webkitRequestFullScreen || docEl.msRequestFullscreen || undefined;
    var cancelFullScreen = doc.exitFullscreen || doc.mozCancelFullScreen || doc.webkitExitFullscreen || doc.msExitFullscreen || undefined;
   
    if (!!!requestFullScreen || !!!cancelFullScreen) {
        alert('fullscreen api not supported');
        return;
    }

    if (!doc.fullscreenElement && !doc.mozFullScreenElement && !doc.webkitFullscreenElement && !doc.msFullscreenElement) {
        requestFullScreen.call(docEl);
    }
    else {
        cancelFullScreen.call(doc);
    }
}

function isImageCached(src) {
    var image = new Image();
    image.src = src;

    return image.complete;
}

function getBatteryLevel() {
    // return -1 or 0-100%

    if (navigator.battery) {
        // firefox support
        return Promise.resolve(Math.floor(navigator.battery.level * 100) + "%");
    }
    if (navigator.getBattery) {
        // chrome support
        return navigator.getBattery().then(function(battery) {
            return Math.floor(battery.level * 100) + "%";
        });
    }
    return Promise.resolve("-1");
}
