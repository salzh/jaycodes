/**
 * The monitor is designed to monitor dynamic (ajax) pages which may
 * add phone numbers after the page load completes.
 * The PageMonitor monitors the lastModified date/time of the current page
 * if it changes it then it waits for the changes to stop and forces
 * a refresh of the page.
 * The interval we use to wait for a change to complete is quite short.
 * In reality, due to the single threaded nature of browsers, the wait timer
 * won't actually be called until the change has completed.
 * Asynchronous ajax calls may break this logic but we need to get the code
 * into the field to determine if this will be a problem.
 *
 * TODO: update the code so that it only adds new click icons rather than
 * 	 simply refreshing the whole page.
 */




noojeeClick.ns(function() { with (noojeeClick.LIB) {

theApp.monitor =
{

Monitor: function ()
{
	this.pageMonitorID = null; // id of the timer which we use to monitor page changes
	this.lastModified = new Date();
	this.lastModificationCheck = new Date();
	this.document = null;
	this.refreshRequired = false;
	this.duration = 400;	// The interval used to check if a page has finished changing.
	this.suppressDomModification = false;
	this.wasModified = false; // Set to true if the page is modified whilst we don't have the focus.
	this.options = {'characterData': true, 'subtree': true, 'childList': true};

	// We only want to monitor the page if it is the active tab.
	// This is a big performance boost when lots of tabs are open.
	this.isActive = true;


	/**
	 * NoojeeClick.js calls the init method to initialises the monitor for each page as the page
	 * is loaded.
	 */
	this.init = function(document)
	{
		var canObserveMutation = 'MutationObserver' in window;
		var self = this;

		this.document = document;

		if (document == null || document.location == null || document.location.href == null)
		{
			return;
		}

		if (canObserveMutation && document.body) {
			this.observer = new MutationObserver( function (q) { self.mutated(q); } );
			this.observer.observe(document.body,  this.options);
		}

		document.addEventListener("focus", function() { self.onFocus(); }, false);
		document.addEventListener("blur", function() { self.onBlur(); }, false);
		/*
		 *
		 * We are taking the monitor function out until mozilla fixes their performance problems.
		 *
		try
		{
			// Special check. It looks like an interaction problem between the monitor
			// and fckEditor. Anyway I'm guessing document has gone away by the time
			// the monitor kicks in. Any reference to the document will throw an error.
			// Given we don't want to add click to dial links to these type of pages
			// we just suppress the error by catching it and returning.


			theApp.logging.njdebug("monitor", "init called for document=" + document);
			this.document = document;
			//var self = this;
			//document.addEventListener("DOMSubtreeModified", function() { self.domModified(); }, false);


		}
		catch (e)
		{
			theApp.logging.njerror("monitor ignoring document with null href");
			return;
		}
		*/

	};

	this.mutated = function (q) {
		//console.log("monitor", q.addedNodes.length, q.removedNodes.length);
		this.wasModified = true;

		if (this.isActive) {
			this.observer.disconnect();
			console.time("monitor");
			theApp.render.onRefreshOne(this.document);
			console.timeEnd("monitor");
			this.observer.observe(this.document.body,  this.options);
			theApp.logging.njdebug("monitor","Mutated");
		}
	};

	/**
	 * When the page becomes active it gets the focus, so lets monitor it.
	 */
	this.onFocus = function()
	{
		this.isActive = true;

		// If the dom was modified whilst not in focus we now need to force a refresh.
		if (this.wasModified == true) this.mutated();
	};

	/**
	 * When the page looses focus we are no longer interested in monitoring it.
	 */
	this.onBlur = function()
	{
		this.isActive = false;
		this.wasModified = false;
	};
},


};

}});
