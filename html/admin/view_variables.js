// View Variables window.
// Kept to old JavaScript so it still works in the 515 client's Internet Explorer browser.
(function () {
	var filterBox = document.getElementById('vv-filter');
	var valuesBox = document.getElementById('vv-search-values');
	var changedBox = document.getElementById('vv-changed-only'); // Not on the list window
	var foldBox = document.getElementById('vv-fold-lists');
	var actions = document.getElementById('vv-actions');
	var countText = document.getElementById('vv-count');
	var varList = document.getElementById('vv-vars');
	var selected = null;

	function hasClass(el, name) {
		return (' ' + el.className + ' ').indexOf(' ' + name + ' ') !== -1;
	}

	function setClass(el, name, on) {
		if (on === hasClass(el, name)) {
			return;
		}
		if (on) {
			el.className += ' ' + name;
		} else {
			el.className = (' ' + el.className + ' ').replace(' ' + name + ' ', ' ').replace(/^\s+|\s+$/g, '');
		}
	}

	// One row per variable. Entries of lists shown inside a variable are inside these rows
	function getRows() {
		var rows = [];
		var children = varList.childNodes;
		for (var i = 0; i < children.length; i++) {
			if (children[i].nodeType === 1 && hasClass(children[i], 'vv-var')) {
				rows.push(children[i]);
			}
		}
		return rows;
	}

	function getVisibleRows() {
		var rows = getRows();
		var visible = [];
		for (var i = 0; i < rows.length; i++) {
			if (rows[i].style.display !== 'none') {
				visible.push(rows[i]);
			}
		}
		return visible;
	}

	function select(row) {
		if (selected) {
			setClass(selected, 'vv-selected', false);
		}
		selected = row;
		if (row) {
			setClass(row, 'vv-selected', true);
		}
	}

	// Scrolls just enough to show the row below the toolbar
	function scrollToRow(row) {
		var rect = row.getBoundingClientRect();
		var top = document.getElementById('vv-toolbar').getBoundingClientRect().bottom;
		var bottom = window.innerHeight || document.documentElement.clientHeight;
		if (rect.top < top) {
			window.scrollBy(0, rect.top - top);
		} else if (rect.bottom > bottom) {
			window.scrollBy(0, rect.bottom - bottom);
		}
	}

	function applyFilter(newSearch) {
		var text = filterBox.value.toLowerCase();
		var rows = getRows();
		var visible = 0;
		var first = null;
		for (var i = 0; i < rows.length; i++) {
			var row = rows[i];
			var match = true;
			if (text) {
				var searched = row.getAttribute('data-name') || '';
				if (valuesBox.checked) {
					var body = row.querySelector('.vv-body');
					searched = (body || row).textContent;
				}
				match = searched.toLowerCase().indexOf(text) !== -1;
			}
			if (match && changedBox && changedBox.checked) {
				match = hasClass(row, 'vv-changed');
			}
			row.style.display = match ? '' : 'none';
			if (match) {
				visible++;
				if (!first) {
					first = row;
				}
			}
		}

		// Typing picks the first match, so Enter edits it
		if (newSearch || (selected && (selected.style.display === 'none' || !selected.parentNode))) {
			select(text ? first : null);
		}

		countText.innerHTML = visible === rows.length ? rows.length + ' shown' : visible + ' of ' + rows.length + ' shown';
	}

	function moveSelection(step) {
		var visible = getVisibleRows();
		if (!visible.length) {
			return;
		}
		var index = -1;
		for (var i = 0; i < visible.length; i++) {
			if (visible[i] === selected) {
				index = i;
				break;
			}
		}
		if (index === -1) {
			index = step > 0 ? 0 : visible.length - 1;
		} else {
			index = Math.max(0, Math.min(visible.length - 1, index + step));
		}
		select(visible[index]);
		scrollToRow(visible[index]);
	}

	function foldAll(folded) {
		var lists = varList.querySelectorAll('.vv-list');
		for (var i = 0; i < lists.length; i++) {
			setClass(lists[i], 'vv-folded', folded);
		}
	}

	// Adds the search box, options and scroll position to a link, so a refresh can put them back
	function withState(href) {
		var options = '';
		if (valuesBox.checked) {
			options += 'v';
		}
		if (changedBox && changedBox.checked) {
			options += 'c';
		}
		if (foldBox.checked) {
			options += 'f';
		}
		var scroll = Math.round(window.pageYOffset || document.documentElement.scrollTop || 0);
		return href + ';vv_filter=' + encodeURIComponent(filterBox.value) + ';vv_scroll=' + scroll + ';vv_options=' + options;
	}

	function go(href) {
		window.location.href = withState(href);
	}

	// Enter on a row edits it, or opens its value if we can't edit
	function openRow(row) {
		var link = null;
		if (!hasClass(document.body, 'vv-readonly')) {
			link = row.querySelector('.vv-edit a');
		}
		if (!link) {
			link = row.querySelector('.vv-body a');
		}
		if (link) {
			go(link.getAttribute('href'));
		}
	}

	function isTyping(el) {
		return el && (el.tagName === 'INPUT' || el.tagName === 'SELECT' || el.tagName === 'TEXTAREA');
	}

	// BYOND sends this after a variable is edited, so the window shows it without a refresh
	window.vvUpdateVar = function (json) {
		var data;
		try {
			data = JSON.parse(json);
		} catch (err) {
			return;
		}
		var oldRow = document.getElementById('vv-var-' + data.name);
		if (oldRow && data.line) {
			var holder = document.createElement('ul');
			holder.innerHTML = data.line;
			var newRow = holder.getElementsByTagName('li')[0];
			if (newRow) {
				oldRow.parentNode.replaceChild(newRow, oldRow);
				if (selected === oldRow) {
					select(newRow);
				}
				if (foldBox.checked) {
					foldAll(true);
				}
				setClass(newRow, 'vv-updated', true);
				setTimeout(function () {
					setClass(newRow, 'vv-updated', false);
				}, 1500);
			}
		}
		if (data.header) {
			document.getElementById('vv-header').innerHTML = data.header;
		}
		if (data.title) {
			document.title = data.title;
		}
		applyFilter(false);
	};

	document.addEventListener('click', function (e) {
		var el = e.target;
		if (hasClass(el, 'vv-fold')) {
			setClass(el.parentNode, 'vv-folded', !hasClass(el.parentNode, 'vv-folded'));
			return;
		}
		while (el && el.tagName !== 'A') {
			el = el.parentNode;
		}
		if (!el) {
			return;
		}
		var href = el.getAttribute('href');
		if (!href || href.indexOf('byond://?_src_=vars') !== 0) {
			return;
		}
		e.preventDefault();
		go(href);
	});

	document.addEventListener('keydown', function (e) {
		var key = e.keyCode;
		var inFilter = document.activeElement === filterBox;

		// F5 refreshes through BYOND, not the browser
		if (key === 116) {
			e.preventDefault();
			go(document.getElementById('vv-refresh').getAttribute('href'));
			return;
		}

		if (inFilter) {
			if (key === 38 || key === 40) { // Up and down arrows
				e.preventDefault();
				moveSelection(key === 40 ? 1 : -1);
			} else if (key === 13) { // Enter
				e.preventDefault();
				if (selected) {
					openRow(selected);
				}
			} else if (key === 27) { // Escape
				filterBox.value = '';
				applyFilter(true);
			}
			return;
		}

		// Typing anywhere else goes to the search box
		if (!isTyping(document.activeElement) && !e.ctrlKey && !e.altKey && !e.metaKey && key >= 48 && key <= 90) {
			filterBox.focus();
		}
	});

	filterBox.addEventListener('input', function () {
		applyFilter(true);
	});

	valuesBox.addEventListener('click', function () {
		applyFilter(true);
	});

	if (changedBox) {
		changedBox.addEventListener('click', function () {
			applyFilter(false);
		});
	}

	foldBox.addEventListener('click', function () {
		foldAll(foldBox.checked);
	});

	actions.addEventListener('change', function () {
		var href = actions.value;
		// Go back to "Actions..." so the same one can be picked again
		actions.selectedIndex = 0;
		if (href) {
			go(href);
		}
	});

	// Put back the search box, options and scroll position from before a refresh
	var body = document.body;
	filterBox.value = decodeURIComponent((body.getAttribute('data-filter') || '').replace(/\+/g, ' '));
	var options = decodeURIComponent(body.getAttribute('data-options') || '');
	valuesBox.checked = options.indexOf('v') !== -1;
	if (changedBox) {
		changedBox.checked = options.indexOf('c') !== -1;
	}
	foldBox.checked = options.indexOf('f') !== -1;
	if (foldBox.checked) {
		foldAll(true);
	}
	applyFilter(true);

	filterBox.focus();
	// Set it again once everything has loaded, since a new window can end up scrolled to the bottom
	var scroll = parseInt(body.getAttribute('data-scroll'), 10) || 0;
	window.scrollTo(0, scroll);
	window.addEventListener('load', function () {
		window.scrollTo(0, scroll);
	});
})();
