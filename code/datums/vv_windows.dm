// View Variables in one window. A reference clicked in a VV window opens in that same window, with Back and Forward,
// instead of opening a new window for every reference. Shift-click still opens a new one.
// The page's script adds the window it's in to every VV link, so the links themselves don't need to know about it.

/// This client's View Variables windows, by window id
/client/var/list/vv_windows
/// How many VV windows this client has opened, used to name new ones
/client/var/vv_window_count = 0

#define VV_HISTORY_MAX 30

/// One View Variables window, and what it has shown for Back and Forward
/datum/vv_window
	var/id
	/// What the window has shown, oldest first. A UID for a datum or client, a ref for a list
	var/list/history = list()
	/// Where in the history the window is now
	var/index = 0

/// The ref VV keeps for D. Lists have no UID
/proc/vv_window_ref(datum/D)
	return islist(D) ? "\ref[D]" : D.UID()

/datum/vv_window/proc/current_ref()
	if(index < 1 || index > length(history))
		return null
	return history[index]

/// The datum or list a history entry is for, or null if it's gone
/datum/vv_window/proc/resolve(ref)
	if(findtext(ref, "]_"))
		var/datum/D = locateUID(ref)
		// locateUID() still finds things that are deleted but not garbage collected yet
		if(isdatum(D) && QDELETED(D))
			return null
		return D
	var/list/L = locate(ref)
	return islist(L) ? L : null

/datum/vv_window/proc/push(datum/D)
	// Going somewhere new drops whatever was ahead in the history
	if(index < length(history))
		history.Cut(index + 1)
	history += vv_window_ref(D)
	if(length(history) > VV_HISTORY_MAX)
		history.Cut(1, 2)
	index = length(history)

/// The window to show D in: the one the link came from, or else one already showing D, or else a new one
/client/proc/vv_window_for(datum/D, window_id)
	LAZYINITLIST(vv_windows)
	// Forget windows the admin has closed
	for(var/id in vv_windows.Copy())
		if(!winexists(src, id))
			vv_windows -= id
	var/datum/vv_window/window = window_id && vv_windows[window_id]
	if(window)
		return window
	var/ref = vv_window_ref(D)
	for(var/id in vv_windows)
		var/datum/vv_window/open = vv_windows[id]
		if(open.current_ref() == ref)
			return open
	window = new
	window.id = "vv[++vv_window_count]"
	vv_windows[window.id] = window
	return window

/// Goes back or forward in a window's history, skipping things that have been deleted
/client/proc/vv_step(window_id, step)
	var/datum/vv_window/window = LAZYACCESS(vv_windows, window_id)
	if(!window)
		return
	var/at = window.index + step
	while(at >= 1 && at <= length(window.history))
		var/datum/D = window.resolve(window.history[at])
		if(D)
			window.index = at
			debug_variables(D, window_id, FALSE)
			return
		// It was deleted, so take it out of the history
		window.history.Cut(at, at + 1)
		if(step < 0)
			window.index--
			at--
	to_chat(src, SPAN_NOTICE("There's nothing [step < 0 ? "before" : "after"] that in this window."))

/// The ids of this client's windows that are showing D right now
/client/proc/vv_windows_showing(datum/D)
	. = list()
	var/ref = vv_window_ref(D)
	for(var/id in vv_windows)
		var/datum/vv_window/window = vv_windows[id]
		if(window.current_ref() == ref)
			. += id

/// The Back and Forward links for the top of the page, greyed out when there's nowhere to go
/proc/vv_nav_links(datum/vv_window/window)
	var/back = window.index > 1 ? "<a href='byond://?_src_=vars;vvback=1'>&lt; Back</a>" : "<font color='#999999'>&lt; Back</font>"
	var/forward = window.index < length(window.history) ? "<a href='byond://?_src_=vars;vvforward=1'>Forward &gt;</a>" : "<font color='#999999'>Forward &gt;</font>"
	return "<font size='1'>[back] | [forward]</font>"

/// The page's script that adds its window to VV links, and puts an edited var's row back in place
/proc/vv_window_script(window_id)
	return {"
			var vv_window = '[window_id]';
			function vv_link(href, new_window) {
				if (href.indexOf('_src_=vars') == -1) return href;
				return href + ';vvwin=' + vv_window + (new_window ? ';vvnew=1' : '');
			}
			document.addEventListener('click', function(e) {
				var a = e.target;
				while (a && a.tagName != 'A') a = a.parentNode;
				if (!a || !a.getAttribute('href')) return;
				var href = a.getAttribute('href');
				if (href.indexOf('_src_=vars') == -1) return;
				e.preventDefault();
				location.href = vv_link(href, e.shiftKey);
			}, true);
			// Called by the server after a var is edited, with the var's name, a colon, then its new row
			function vv_row(what) {
				var split = what.indexOf(':');
				var old = document.getElementById('vvar_' + what.substr(0, split));
				if (!old) return;
				var holder = document.createElement('ol');
				holder.innerHTML = what.substr(split + 1);
				var row = holder.firstElementChild;
				if (row) old.parentNode.replaceChild(row, old);
			}
	"}

/// Where an atom is: what it's inside, out to the turf and area, and who's carrying it. Each one opens in VV.
/proc/vv_where(atom/A)
	if(!istype(A) || isarea(A))
		return ""
	if(isturf(A))
		var/area/turf_area = get_area(A)
		return "<br><font size='1'>[turf_area ? "[ADMIN_VV(turf_area, html_encode(turf_area.name))] " : ""]([A.x], [A.y], [A.z]) [ADMIN_JMP(A)]</font>"
	if(!A.loc)
		return "<br><font size='1'>Nowhere (in nullspace)</font>"
	var/list/chain = list()
	var/mob/carrier
	var/atom/container = A.loc
	var/steps = 0
	while(container && !isturf(container) && steps++ < 20)
		if(!carrier && ismob(container))
			carrier = container
		// Use the name, since "[container]" would add "The" in front
		chain.Insert(1, ADMIN_VV(container, html_encode(container.name)))
		container = container.loc
	var/turf/T = get_turf(A)
	var/list/out = list()
	if(T)
		var/area/turf_area = get_area(T)
		if(turf_area)
			out += ADMIN_VV(turf_area, html_encode(turf_area.name))
		out += ADMIN_VV(T, "([T.x], [T.y], [T.z])")
	out += chain
	. = "<br><font size='1'>In: [out.Join(" &gt; ")][T ? " [ADMIN_JMP(T)]" : ""]</font>"
	if(carrier)
		. += "<br><font size='1'>Carried by: [ADMIN_VV(carrier, html_encode(carrier.name))][carrier.ckey ? " ([carrier.ckey])" : ""] [ADMIN_FLW(carrier, "FLW")]</font>"

/// Puts an edited var's row back with its new value, in every window of this client that's showing D
/client/proc/vv_refresh_var(datum/D, var_name)
	if(!istype(D) || !(var_name in D.vars) || !D.can_vv_get(var_name))
		return
	var/row = D.vv_get_var(var_name)
	for(var/id in vv_windows_showing(D))
		src << output(url_encode("[var_name]:[row]"), "[id].browser:vv_row")

/// A list edited from its own window shows the change there
/client/proc/vv_reshow_list(list/href_list)
	if(!href_list["vvwin"])
		return
	for(var/edit_link in list("listedit", "listchange", "listremove", "listadd", "listdupes", "listnulls", "listlen", "listshuffle"))
		if(!href_list[edit_link])
			continue
		var/list/L = locate(href_list[edit_link])
		if(islist(L))
			debug_variables(L, href_list["vvwin"], FALSE)
		return

#undef VV_HISTORY_MAX
