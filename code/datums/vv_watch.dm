// View Variables can watch vars live. "watch" by a var puts it in a Watching box at the top of the page, which updates every
// second while the window shows that thing, so you can see health dropping or a mob walking. Pressing "watch" again or the
// box's x stops it, and so does going to another page, closing the window, or the thing being deleted.

GLOBAL_DATUM_INIT(vv_watcher, /datum/vv_watcher, new)

/// Sends the watched vars of every VV window that has some
/datum/vv_watcher
	/// The windows watching something
	var/list/windows = list()
	/// Whether watch_loop() is running
	var/running = FALSE

/datum/vv_watcher/proc/add(datum/vv_window/window)
	windows |= window
	if(!running)
		INVOKE_ASYNC(src, PROC_REF(watch_loop))

/// Sends the watched vars every second until nothing is watched.
/// This is a loop rather than a processing subsystem so that it also works in the lobby, where those don't fire.
/datum/vv_watcher/proc/watch_loop()
	running = TRUE
	var/next_prune = world.time + 3 SECONDS
	while(length(windows))
		for(var/datum/vv_window/window as anything in windows.Copy())
			var/client/C = window.owner
			if(!C || !length(window.watching) || LAZYACCESS(C.vv_windows, window.id) != window)
				windows -= window
				continue
			C << output(url_encode(vv_watch_json(window)), "[window.id].browser:vv_watch")
			// Say it was deleted once, then stop
			if(!window.resolve(window.current_ref()))
				window.watching = null
		// Stop watching in windows the admin closed
		if(world.time >= next_prune)
			next_prune = world.time + 3 SECONDS
			for(var/datum/vv_window/window as anything in windows.Copy())
				var/client/C = window.owner
				if(!C || !winexists(C, window.id) || winget(C, window.id, "is-visible") == "false")
					window.watching = null
					windows -= window
		sleep(1 SECONDS)
	running = FALSE

/// The watched vars' values right now, for the page
/proc/vv_watch_json(datum/vv_window/window)
	var/datum/D = window.resolve(window.current_ref())
	if(!D)
		return json_encode(list("gone" = TRUE))
	var/list/rows = list()
	for(var/var_name in window.watching)
		if(!(var_name in D.vars) || !D.can_vv_get(var_name))
			continue
		rows += list(list(var_name, vv_watch_value(D.vars[var_name])))
	return json_encode(list("rows" = rows, "time" = gameTimestamp()))

/// A value as short text for the Watching box
/proc/vv_watch_value(value)
	if(isnull(value))
		return "null"
	if(istext(value))
		return length(value) > 100 ? "\"[copytext(value, 1, 98)]...\"" : "\"[value]\""
	if(islist(value))
		var/list/L = value
		return "/list ([length(L)])"
	if(isatom(value))
		var/atom/A = value
		return "[A.name] ([A.type])"
	if(isdatum(value))
		var/datum/D = value
		return "[D.type]"
	return "[value]"

/// Starts or stops watching a var in a VV window
/client/proc/vv_toggle_watch(datum/D, var_name, window_id)
	var/datum/vv_window/window = LAZYACCESS(vv_windows, window_id)
	if(!isdatum(D) || !window || window.current_ref() != vv_window_ref(D) || !(var_name in D.vars))
		return
	if(var_name in window.watching)
		window.watching -= var_name
	else
		LAZYADD(window.watching, var_name)
		GLOB.vv_watcher.add(window)
	src << output(url_encode(vv_watch_json(window)), "[window.id].browser:vv_watch")

/// The Watching box and the script that fills it in
/proc/vv_watch_html(datum/vv_window/window)
	return {"
		<div id='vv_watch' style='display:none'><hr><font size='1'><b>Watching</b> <span id='vv_watch_time'></span></font><ul id='vv_watch_rows'></ul></div>
		<script type='text/javascript'>
			function vv_watch(json) {
				var data = JSON.parse(json);
				var box = document.getElementById('vv_watch');
				var list = document.getElementById('vv_watch_rows');
				while (list.firstChild) list.removeChild(list.firstChild);
				if (data.gone) {
					box.style.display = '';
					list.innerHTML = '<li><font color="red">Deleted.</font></li>';
					return;
				}
				if (!data.rows || !data.rows.length) {
					box.style.display = 'none';
					return;
				}
				box.style.display = '';
				document.getElementById('vv_watch_time').textContent = data.time ? '(round time ' + data.time + ')' : '';
				for (var i = 0; i < data.rows.length; i++) {
					var name = data.rows\[i\]\[0\];
					var li = document.createElement('li');
					var stop = document.createElement('a');
					stop.textContent = 'x';
					var row = document.getElementById('vvar_' + name);
					var watch_link = row ? row.querySelector('a\[href*=vvwatch\]') : null;
					if (watch_link) stop.href = watch_link.getAttribute('href');
					li.appendChild(document.createTextNode('('));
					li.appendChild(stop);
					li.appendChild(document.createTextNode(') ' + name + ' = '));
					var value = document.createElement('span');
					value.className = 'value';
					value.textContent = data.rows\[i\]\[1\];
					li.appendChild(value);
					list.appendChild(li);
				}
			}
			[length(window.watching) ? "vv_watch([json_encode(vv_watch_json(window))]);" : ""]
		</script>
	"}
