/**
 * History window object
 * @param {VelantroStorage} storage DI of sqlite storage
 * @param {Velantro} api velantro API class
 */
function VelantroHistory (storage, api) {
	this.storage = storage;
	this.api = api;
}
/**
 * Show history window
 */
VelantroHistory.prototype.show = function () {
	var o = this;
	window.openDialog("chrome://noojeeclick/content/xul/history.xul",
		"showmore",
        "chrome", this.storage.getCalls(), function (t, phone) { o.go(t, phone) });
}
/**
 * Click buttons within dialog (Call or CRM).
 * @param {string} t What to do ("call" or "crm")
 */
VelantroHistory.prototype.go = function (t, phone) {
	if (t == "call") this.api.dial(phone);
	if (t == "crm") this.api.sendToCRM(phone);
}

function VelantroStorage () {
	var file = Components.classes["@mozilla.org/file/directory_service;1"]
            	.getService(Components.interfaces.nsIProperties)
                .get("ProfD", Components.interfaces.nsIFile);
	var storageService = Components.classes["@mozilla.org/storage/service;1"]
				.getService(Components.interfaces.mozIStorageService);
	var res;
	file.append("velantro.sqlite");
	this.conn = storageService.openDatabase(file);
	if (!this.conn.tableExists("Calls")) {
		res = this.conn.executeSimpleSQL("CREATE TABLE Calls \
( \
	id INTEGER PRIMARY KEY AUTOINCREMENT, \
	time INTEGER, \
	party TEXT, \
	dir INTEGER, \
	duration INTEGER \
)");
	}
}

/**
 * Save call info.
 * @param {number} time UNIX timestamp of start time
 * @param {number} dir Direction of call (1 -- in, 2 -- out).
 * @param {string} party CALLER or CALEE
 * @param {number} duration Duration of call in seconds
 */
VelantroStorage.prototype.saveCall = function (tme, dir, party, duration) {
	var statement = this.conn.createStatement(
		 "INSERT INTO Calls \
		(time, party, dir, duration)  VALUES \
		(:tme, :party, :dir, :duration)"
	);
	statement.params.tme = tme;
	statement.params.dir = dir;
	statement.params.party = party;
	statement.params.duration = duration;
	statement.execute();
	statement.reset();
	// Delete old items
	statement = this.conn.createStatement(
		 "DELETE FROM Calls WHERE time < :tme"
	);
	statement.params.tme = Math.floor(Date.now() / 1000) - 3600*24*7;
	statement.execute();
	statement.reset();
}

/**
 * Get calls list.
 * @return {array} Array of calls
 */
VelantroStorage.prototype.getCalls = function () {
	var statement = this.conn.createStatement(
		 "SELECT * FROM Calls ORDER BY time DESC"
	);
	var tme = statement.getColumnIndex("time");
	var party = statement.getColumnIndex("party");
	var dir = statement.getColumnIndex("dir");
	var duration = statement.getColumnIndex("duration");
	var arr = [], row;
	var time, h, m, s;
	while (statement.executeStep()) {
  		//console.log("Row:", statement.getString());
		row = [];
		time = new Date(statement.getInt32(tme) * 1000);
		row[0] = time.toLocaleDateString("en-US") + " " + time.toLocaleTimeString("en-us");
		row[2] = statement.getString(party);
		row[1] = statement.getInt32(dir)==1?"in":"out";
		row[3] = statement.getInt32(duration);
		s = row[3] % 60;
		m = Math.floor((row[3] - s) / 60) % 60;
		h = Math.floor((row[3] - s - m) / 60 / 60);
		row[3] = this.pad(h) + ":" +this.pad(m) + ":" + this.pad(s)	;
		arr.push(row);
	}
	return arr;
}
/**
 * Pad string left
 * @param {string} s string to pad left
 */
VelantroStorage.prototype.pad = function (s) {
	var pad = "00";
	var str = s + "";
	return pad.substring(0, pad.length - str.length) + str;
}

/**
 * Incoming call class
 * @param {Array} config
 * @param {VelantroStorage} storage DI of sqlite storage
 */
function VelantroCall (fascade) {
	this.callid = null;         // Incoming call ID
	this.fascade = fascade;
	this.storage = fascade.storage;
	this.cfg = fascade.cfg;
	this.ignoring = {};			// Incoming call IDs we should ignore
	this.prepareListener();
}

VelantroCall.prototype.prepareListener = function () {
		var o = this;
		this.evsource = new window.EventSource(this.cfg.sse+"&ext="+this.cfg.ext);
		this.evsource.addEventListener('message', function(e) {
			o.gotMessage(e);
		}, false);
}

VelantroCall.prototype.gotMessage = function (msg) {
	var data = JSON.parse(msg.data);
	// console.log("Velantro SSE event:", data);
	switch(data.current_state.toLowerCase()) {
	case "active":
		this.fascade.sendToCRM('000');
		break;
	case "ringing":
	case "down":
		// Skip rings on calls witch is in ignore
		if  (this.ignoring[data.uuid]) return;
		this.storage.saveCall(
			Math.floor(Date.now() / 1000),
			1,
			data.caller,
			0
		);
		this.enable(data.caller);
		this.callid = data.uuid;
		break;
	case "hangup":
	case "nocall":
		this.disable();
		break;
	}
}

VelantroCall.prototype.enable = function (from) {
	document.getElementById('VelantroCallToolbar').setAttribute('hidden', 'false');
	this.displayCID(from);
}

VelantroCall.prototype.displayCID = function (from) {
	var re = /(.*)<([0-9]*)>/;
	var res;
	if (res = from.match(re)) {
		document.getElementById('VelantroCallCID').value = res[2];
		document.getElementById('VelantroCallName').value = res[1];
	} else {
		document.getElementById('VelantroCallCID').value = from;
	}
}


VelantroCall.prototype.disable = function () {
	document.getElementById('VelantroCallToolbar').setAttribute('hidden', 'true');
}

VelantroCall.prototype.ignore = function () {
	this.disable();
	this.ignoring[this.callid] = true;
}

VelantroCall.prototype.sendTransfer = function () {
    var reg = /^[ \t\(\)0-9-]+$/;
	var tr = document.getElementById("VelantroCallTransferTo");
    var to = tr.value;
	var param = [];
	var o = this;
	tr.classList.remove("VelantroError");
    if (reg.test(to)) {
		param.push(this.cfg.calltransfer);
		param.push("dest="+this.fascade.clearNumber(to));
		param.push("uuid="+this.callid);
		this.fascade.sendAjax(
			param.join("&"),
			function (res) { o.gotState(res) }
		);
    } else {
		tr.classList.add("VelantroError");
    }
}

VelantroCall.prototype.gotState = function (resp) {
	//console.log("GOT", resp);
}

noojeeClick.ns(function() { with (noojeeClick.LIB) {

theApp.velantro = {
init: function (storage) {
	this.storage = storage;
	this.callbackid = null;		// Callback we'd placed
	this.timer = null; 			// Timer to poll state during a call
	this.closetimer = null;		// Timer to hide tollbar after a call
	this.hangup = false;		// Used to stop polling
	this.statecheck = 1000;		// Polling interval
	this.inicfg = {
    	getsession: "/api/api.pl?action=sendcallback",
    	getstate: "/api/api.pl?action=getcallbackstate",
    	hangup: "/api/api.pl?action=hangup",
    	transfer: "/api/api.pl?action=transfer",
		sse: "/api/api.pl?action=getincomingevent",
		calltransfer: "/api/api.pl?action=transferincoming"
	};
	this.cfg = {};
	this.setcfg();
	this.incoming = new VelantroCall(this);
	this.prefs = Components.classes["@mozilla.org/preferences-service;1"]
		.getService(Components.interfaces.nsIPrefService)
		.getBranch("extensions.noojeeclick.");
	this.prefs.addObserver("", this, false);
},
observe: function (x) {
	this.setcfg()
},
sendAjax: function (path, cb) {
	var xmlhttp = new XMLHttpRequest();
	xmlhttp.overrideMimeType('application/json');
	xmlhttp.onload = function() {
		  //ready = (xmlhttp.readyState == 4 && xmlhttp.status == 200);
		  //cb(ready ? xmlhttp.responseText : false);
		  cb(xmlhttp.responseText);
	};
	xmlhttp.open('GET', path, true);
	xmlhttp.send();
},
gotSession: function (res) {
	var o = this;
	var obj = JSON.parse(res);
	this.callbackid = obj.callbackid;
	this.timer = setTimeout(function () { o.checkState() }, this.statecheck);
},
checkState: function (cfg, add) {
	var o = this;
	var par = [];
    if (cfg) par.push(cfg);
    else par.push(this.cfg.getstate);
    par.push("callbackid="+this.callbackid);
    if (add) par.push(add);
	this.sendAjax(
		par.join("&"),
		function (res) { o.gotState(res) }
	);
},
gotState: function (res) {
	 console.log("Velantro response:",res);
		var o = this;
		var status = document.getElementById("VelantroStatus");
		switch (JSON.parse(res).state) {
			case "HANGUP":
				this.hangup = true;
				status.value = "Hangup";
				this.disable();
				if (this.callstarts) {
					this.storage.saveCall(
						this.callstarts,
						2,
						document.getElementById('VelantroPhone').value,
						this.callstarts?(Math.floor(Date.now() / 1000) - this.callstarts):0
					);
				}
				this.callstarts = null;
				break;
			case "RINGING":
			case "RING_WAIT":
				status.value = "Ringing";
				break;
		case "ACTIVE":
				this.callstarts = Math.floor(Date.now() / 1000);
				status.value = "Active";
				
				break;
		}
		if (!this.hangup)
			setTimeout(function () { o.checkState() }, this.statecheck);
},
sendTransfer: function () {
        var reg = /^[ \t\(\)0-9-]+$/;
		var tr = document.getElementById("VelantroTransferTo");
        var to = tr.value;
		tr.classList.remove("VelantroError");
        if (reg.test(to)) {
            this.checkState(this.cfg.transfer, "dest="+this.clearNumber(to));
        } else {
			tr.classList.add("VelantroError");
        }
},
sendHangup: function () {
		this.checkState(this.cfg.hangup);
},
clearNumber: function (n) {
		return n.replace(/[^0-9]/g, "");
},
enable: function () {
		document.getElementById('VelantroToolbar').removeAttribute('hidden', 'false');
		document.getElementById("VelantroHangup").setAttribute('disabled', 'false');
		document.getElementById("VelantroTransfer").setAttribute('disabled', 'false');
		document.getElementById("VelantroTransferTo").removeAttribute('disabled');
},
disable: function () {
	var o = this;
	document.getElementById("VelantroHangup").setAttribute('disabled', 'true');
	document.getElementById("VelantroTransfer").setAttribute('disabled', 'true');
	document.getElementById("VelantroTransferTo").setAttribute('disabled', 'true');
	if (this.closetimer == null) {
		this.closetimer = setTimeout(function () {
			document.getElementById('VelantroToolbar').setAttribute('hidden', 'true');
			o.closetimer = null;
		}, 5000);
	}

},
dial: function (dest) {
        var qs = [], o = this;
		this.hangup = false;
		this.setcfg();
		qs.push("ext=" + this.cfg.ext);
		qs.push("dest=" + dest);
		qs.push("callerid=" + this.cfg.callerid);
		qs.push("autoanswer=" + this.cfg.autoanswer)
        this.sendAjax(
            this.cfg.getsession + "&" + qs.join("&"),
            function (res) { o.gotSession(res) }
        );
        document.getElementById('VelantroPhone').value = this.clearNumber(dest);
        this.enable();
},
setcfg: function () {
		var host = theApp.prefs.getValue("host");
		var port = theApp.prefs.getValue("port");
		if ((port == "80") || (port == "")) port = "";
		else port = ":"+port;
		if (host == "") {
			alert ("Set host address in extention options");
			return;
		}
		this.cfg.callerid = this.clearNumber(theApp.prefs.getValue("callerId"));
		this.cfg.ext = theApp.prefs.getValue("extension");
		this.cfg.autoanswer = theApp.prefs.getBoolValue("enableAutoAnswer")?"1":"0";
		this.cfg.getsession = "http://"+host+port+this.inicfg.getsession;
		this.cfg.getstate = "http://"+host+port+this.inicfg.getstate;
		this.cfg.hangup = "http://"+host+port+this.inicfg.hangup;
		this.cfg.transfer = "http://"+host+port+this.inicfg.transfer;
		this.cfg.sse = "http://"+host+port+this.inicfg.sse;
		this.cfg.calltransfer = "http://"+host+port+this.inicfg.calltransfer;
		//this.cfg.sse = "http://www.asmi.spb.ru/gate.php";
},
sendToCRM: function (no) {
	var url = theApp.prefs.getValue("crm").replace(/%/, no);
	var win = Components.classes['@mozilla.org/appshell/window-mediator;1']
        .getService(Components.interfaces.nsIWindowMediator)
        .getMostRecentWindow('navigator:browser');
    win.gBrowser.selectedTab = win.gBrowser.addTab(url + '&ext=' + this.cfg.ext);
},
sendCallTransfer: function () { this.incoming.sendTransfer(); },
ignoreCall: function () { this.incoming.ignore(); }
}


document.getElementById('VelantroToolbar').setAttribute('hidden', 'true');
theApp.velantroStorage = new VelantroStorage();
theApp.velantro.init(theApp.velantroStorage);
//theApp.velantroStorage.saveCall(1428244018, 2, "3288128", 3601);
theApp.velantroHistory = new VelantroHistory(
	theApp.velantroStorage,
	theApp.velantro
);
// console.log("Velantro.js loaded");

}});
