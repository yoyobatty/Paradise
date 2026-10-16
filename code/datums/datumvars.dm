// reference: /client/proc/modify_variables(var/atom/O, var/param_var_name = null, var/autodetect_class = 0)

/// How many lists deep VV will show the contents of lists inside lists
#define VV_MAX_LIST_DEPTH 5

/**
  * Proc to check if a datum allows proc calls on it
  *
  * Returns TRUE if you can call a proc on the datum, FALSE if you cant
  *
  */
/datum/proc/CanProcCall(procname)
	return TRUE

/datum/proc/can_vv_get(var_name)
	return TRUE

/mob/can_vv_get(var_name)
	var/static/list/protected_vars = list(
		"lastKnownIP", "computer_id", "attack_log_old"
	)
	if(!check_rights(R_ADMIN, FALSE, usr) && (var_name in protected_vars))
		return FALSE
	return TRUE

/client/can_vv_get(var_name)
	var/static/list/protected_vars = list(
		"address", "computer_id", "connection", "jbh", "pm_tracker", "related_accounts_cid", "related_accounts_ip", "watchlisted"
	)
	if(!check_rights(R_ADMIN, FALSE, usr) && (var_name in protected_vars))
		return FALSE
	return TRUE

/datum/proc/vv_edit_var(var_name, var_value) //called whenever a var is edited
	switch(var_name)
		if("vars")
			return FALSE
		if("var_edited")
			return FALSE
	var_edited = TRUE
	vars[var_name] = var_value

	. = TRUE


/client/vv_edit_var(var_name, var_value) //called whenever a var is edited
	switch(var_name)
		// I know we will never be in a world where admins are editing client vars to let people bypass TOS
		// But guess what, if I have the ability to overengineer something, I am going to do it
		if("tos_consent")
			return FALSE
		// Dont fuck with this
		if("cui_entries")
			return FALSE
		// or this
		if("jbh")
			return FALSE
		if("vars")
			return FALSE
		if("var_edited")
			return FALSE
	var_edited = TRUE
	vars[var_name] = var_value

	. = TRUE

/datum/proc/vv_get_var(var_name)
	switch(var_name)
		if("attack_log_old", "debug_log")
			return debug_variable(var_name, vars[var_name], 0, src, sanitize = FALSE)
		if("vars")
			return debug_variable(var_name, list(), 0, src)
	return debug_variable(var_name, vars[var_name], 0, src)

/client/vv_get_var(var_name)
	switch(var_name)
		if("vars")
			return debug_variable(var_name, list(), 0, src)
	return debug_variable(var_name, vars[var_name], 0, src)

/datum/proc/can_vv_delete()
	return TRUE

//please call . = ..() first and append to the result, that way parent items are always at the top and child items are further down
//add seperaters with VV_DROPDOWN_SEPARATOR
/datum/proc/vv_get_dropdown()
	SHOULD_CALL_PARENT(TRUE)

	. = list()

	VV_DROPDOWN_SEPARATOR
	VV_DROPDOWN_OPTION(VV_HK_PROC_CALL, "Call Proc")
	VV_DROPDOWN_OPTION(VV_HK_MARK_OBJECT, "Mark Object")
	VV_DROPDOWN_OPTION(VV_HK_JUMP_TO, "Jump to Object")
	VV_DROPDOWN_OPTION(VV_HK_DELETE, "Delete")
	VV_DROPDOWN_OPTION(VV_HK_TRAITMOD, "Modify Traits")
	VV_DROPDOWN_OPTION(VV_HK_ADDCOMPONENT, "Add Component/Element")
	VV_DROPDOWN_OPTION(VV_HK_REMOVECOMPONENT, "Remove Component/Element")
	VV_DROPDOWN_OPTION(VV_HK_MASSREMOVECOMPONENT, "Mass Remove Component/Element")
	VV_DROPDOWN_SEPARATOR

/**
 * This proc is only called if everything topic-wise is verified. The only verifications that should happen here is things like permission checks!
 * href_list is a reference, modifying it in these procs WILL change the rest of the proc in topic.dm of admin/view_variables!
 * This proc is for "high level" actions like admin heal/set species/etc/etc. The low level debugging things should go in admin/view_variables/topic_basic.dm in case this runtimes.
 */
/datum/proc/vv_do_topic(list/href_list)
	if(!usr || !usr.client || !usr.client.holder || !check_rights(R_VAREDIT))
		return FALSE //This is VV, not to be called by anything else.
	if(href_list[VV_HK_MODIFY_TRAITS])
		usr.client.holder.modify_traits(src)

	return TRUE

/datum/proc/vv_get_header()
	. = list()

/client/vv_get_dropdown()
	. = ..()

	VV_DROPDOWN_OPTION(VV_HK_MANIPULATE_COLOR_MATRIX, "Manipulate Color Matrix")

/client/vv_do_topic(list/href_list)
	. = ..()

	if(!.)
		return

	if(href_list[VV_HK_MANIPULATE_COLOR_MATRIX])
		if(!check_rights(R_DEBUG))
			return

		message_admins("[key_name_admin(usr)] is manipulating the colour matrix for [src]")
		var/datum/ui_module/colour_matrix_tester/CMT = new(target=src)
		CMT.ui_interact(usr)

USER_CONTEXT_MENU(debug_variables, R_ADMIN|R_VIEWRUNTIMES, "\[Admin\] View Variables", datum/thing in world)
	client.debug_variables(thing)

/**
 * Opens the View Variables window for a datum, client or list, or refreshes it if it's already open.
 *
 * page_state is the href_list of the link that asked for the refresh.
 * The window adds its search box and scroll position to its links, so a refresh keeps them.
 */
/client/proc/debug_variables(datum/D in world, list/page_state)
	if(!D)
		return

	var/islist = islist(D)
	var/isclient = isclient(D)
	if(!islist && !isclient && !istype(D))
		return

	var/datum/asset/asset_cache_datum = get_asset_datum(/datum/asset/simple/vv)
	asset_cache_datum.send(src)

	var/refid
	var/title
	var/refresh_link
	var/legend
	var/list/dropdownoptions
	if(islist)
		var/list/L = D
		refid = "\ref[L]"
		title = "/list ([length(L)])"
		refresh_link = "byond://?_src_=vars;listrefresh=[refid]"
		legend = "<b>E</b> edits an entry, <b>C</b> asks for its type first, <b>-</b> removes it."
		dropdownoptions = list(
			"<option value='byond://?_src_=vars;listadd=[refid]'>Add Item</option>",
			"<option value='byond://?_src_=vars;listnulls=[refid]'>Remove Nulls</option>",
			"<option value='byond://?_src_=vars;listdupes=[refid]'>Remove Dupes</option>",
			"<option value='byond://?_src_=vars;listlen=[refid]'>Set len</option>",
			"<option value='byond://?_src_=vars;listshuffle=[refid]'>Shuffle</option>"
		)
	else
		refid = D.UID()
		title = vv_window_title(D)
		refresh_link = "byond://?_src_=vars;datumrefresh=[refid]"
		legend = "<b>E</b> edits a variable, <b>C</b> asks for its type first, <b>M</b> changes it on every one of this type."
		dropdownoptions = D.vv_get_dropdown()

	var/header = vv_header_html(D)

	sleep(1) // Without a sleep here, VV sometimes disconnects clients

	var/list/variable_html = list()
	if(islist)
		var/list/L = D
		for(var/i in 1 to length(L))
			variable_html += debug_list_entry(L, i)
	else
		var/list/names = list()
		for(var/V in D.vars)
			names += V
		names = sortList(names)
		for(var/V in names)
			if(!D.can_vv_get(V))
				continue
			var/line = D.vv_get_var(V)
			// Some types hide a var by returning FALSE from vv_get_var()
			if(istext(line))
				variable_html += line

	// Put the search box and scroll position back after a refresh
	var/filter_text = ""
	var/scroll = 0
	var/options = ""
	if(page_state)
		filter_text = page_state["vv_filter"] || ""
		scroll = text2num(page_state["vv_scroll"]) || 0
		options = page_state["vv_options"] || ""

	// Clients with just R_VIEWRUNTIMES don't get the edit buttons
	var/readonly = !check_rights_client(R_VAREDIT, FALSE, src)

	var/html = {"<!DOCTYPE html>
<html>
	<head>
		<meta charset="UTF-8">
		<meta http-equiv="X-UA-Compatible" content="IE=edge">
		<title>[html_encode(title)]</title>
		<link rel="stylesheet" type="text/css" href="[SSassets.transport.get_asset_url("view_variables.css")]">
		[window_scaling ? "<style>body {zoom: [100 / window_scaling]%;}</style>" : ""]
	</head>
	<body class='[readonly ? "vv-readonly" : ""]' data-filter="[url_encode(filter_text)]" data-scroll="[round(scroll)]" data-options="[url_encode(options)]">
		<div id='vv-header'>[header]</div>
		<div id='vv-toolbar'>
			<div class='vv-toolbar-row'>
				<a id='vv-refresh' class='vv-button' href='[refresh_link]' title='Refresh (F5)'>Refresh</a>
				<select id='vv-actions'>
					<option value='' selected>Actions...</option>
					[dropdownoptions.Join()]
				</select>
			</div>
			<div class='vv-toolbar-row'>
				<input type='text' id='vv-filter' placeholder='[islist ? "Search entries" : "Search variables"]' autocomplete='off'>
			</div>
			<div class='vv-toolbar-row vv-options'>
				<label title='Search the values as well as the names'><input type='checkbox' id='vv-search-values'>Values</label>
				[islist ? "" : "<label title='Only show variables that are different from their default value'><input type='checkbox' id='vv-changed-only'>Changed</label>"]
				<label title='Fold up the lists shown inside variables'><input type='checkbox' id='vv-fold-lists'>Fold lists</label>
				<span id='vv-count'></span>
			</div>
		</div>
		<ul id='vv-vars'>
			[variable_html.Join()]
		</ul>
		<div id='vv-legend'>[legend] Use the arrow keys and Enter in the search box to pick and edit one.</div>
		<script type='text/javascript' src='[SSassets.transport.get_asset_url("view_variables.js")]'></script>
	</body>
</html>
"}

	if(istype(D, /datum))
		log_admin("[key_name(usr)] opened VV for [D] ([D.UID()])")

	var/size_string = window_scaling ? "size=[520 * window_scaling]x[700 * window_scaling]" : "size=520x700"
	src << browse(html, "window=[VV_WINDOW_ID(refid)];[size_string]")

/// The window title, like "Urist McTest - /mob/living/carbon/human"
/proc/vv_window_title(datum/D)
	var/name = "[D]"
	if(name == "[D.type]")
		return name
	return "[name] - [D.type]"

/// The top of a VV window: the sprite, name, type, where it is and tags like "Marked"
/client/proc/vv_header_html(datum/D)
	if(islist(D))
		var/list/L = D
		return "<div class='vv-header-info'><div class='vv-name-line'><b>/list ([length(L)])</b></div><div class='vv-ref'>\ref[L]</div></div>"

	var/list/html = list()
	var/atom/A = isatom(D) ? D : null
	if(A?.icon && A.icon_state)
		// Diagonal facings fall back to south, since most icons only have four directions
		var/sprite_dir = (A.dir in GLOB.cardinal) ? A.dir : SOUTH
		var/icon/sprite = new /icon(A.icon, A.icon_state, sprite_dir, 1)
		var/hash = md5("[md5(A.icon)][A.icon_state][sprite_dir]")
		src << browse_rsc(sprite, "vv[hash].png")
		html += "<img class='vv-sprite' src='vv[hash].png'>"

	var/list/header = D.vv_get_header()
	if(!length(header))
		header = list("<b>[html_encode("[D]")]</b>")
	html += "<div class='vv-header-info'>"
	html += "<div class='vv-name-line'>[header.Join()]</div>"
	html += "<div class='vv-type'>[D.type]</div>"
	html += "<div class='vv-ref'>\ref[D]</div>"

	if(A)
		var/list/where = list()
		var/turf/T = get_turf(A)
		if(A.loc && A.loc != T)
			where += "In [ADMIN_VV(A.loc, html_encode("[A.loc]"))]"
		if(T)
			var/area/our_area = get_area(T)
			where += "At [ADMIN_VV(our_area, html_encode("[our_area]"))] <a href='byond://?_src_=holder;adminplayerobservecoodjump=1;X=[T.x];Y=[T.y];Z=[T.z]' title='Jump here'>([T.x], [T.y], [T.z])</a>"
		if(length(where))
			html += "<div class='vv-where'>[where.Join(", ")]</div>"

	var/list/tags = list()
	if(holder?.marked_datum == D)
		tags += "Marked"
	if(A?.admin_spawned)
		tags += "Admin spawned"
	if(D.var_edited)
		tags += "Var edited"
	if(QDELETED(D))
		tags += "Deleted"
	if(length(tags))
		html += "<div class='vv-tags'><span class='vv-tag'>[tags.Join("</span><span class='vv-tag'>")]</span></div>"

	html += "</div>"
	return html.Join()

/// Shows a var's new value in its open VV window, without reloading the window
/client/proc/vv_update_var(datum/D, var_name)
	if(!istype(D) && !isclient(D))
		return
	if(!(var_name in D.vars) || !D.can_vv_get(var_name))
		return
	var/line = D.vv_get_var(var_name)
	var/list/update = list(
		"name" = var_name,
		"line" = istext(line) ? line : null,
		"header" = vv_header_html(D),
		"title" = vv_window_title(D)
	)
	src << output(url_encode(json_encode(update)), "[VV_WINDOW_ID(D.UID())].browser:vvUpdateVar")

#define VV_HTML_ENCODE(thing) ( sanitize ? html_encode(thing) : thing )

/// A var of a datum with its edit buttons, or an entry of a list shown inside one (when level > 0)
/proc/debug_variable(name, value, level, datum/owner, sanitize = TRUE)
	var/value_html = _debug_variable_value(name, value, level, owner, sanitize)
	if(level > 0 || !owner)
		return "<li>[debug_variable_key(name, sanitize)] = [value_html]</li>"

	var/uid = owner.UID()
	var/changed_class = ""
	var/name_title = ""
	var/default_text = vv_changed_default(owner, name, value)
	if(default_text)
		changed_class = " vv-changed"
		name_title = " title=\"Default: [html_encode(default_text)]\""

	var/edit_links = "<span class='vv-edit'>\
		<a href='byond://?_src_=vars;datumedit=[uid];varnameedit=[name]' title='Edit'>E</a>\
		<a href='byond://?_src_=vars;datumchange=[uid];varnamechange=[name]' title='Pick the type, then edit'>C</a>\
		<a href='byond://?_src_=vars;datummass=[uid];varnamemass=[name]' title='Change it on every one of this type'>M</a>\
		</span>"
	return "<li class='vv-var[changed_class]' id='vv-var-[name]' data-name='[name]'>[edit_links]<span class='vv-body'><span class='vv-name'[name_title]>[name]</span> = [value_html]</span></li>"

/// One entry of the list window, with its edit buttons
/proc/debug_list_entry(list/L, index)
	var/key = L[index]
	var/value
	if(IS_NORMAL_LIST(L) && !isnum(key))
		value = L[key]

	var/entry
	// No value means it's a normal entry and not an associated one
	if(isnull(value))
		entry = _debug_variable_value(index, key, 1, L, TRUE)
	else
		entry = "[debug_variable_key(key, TRUE)] = [_debug_variable_value(key, value, 1, L, TRUE)]"

	var/list_ref = "\ref[L]"
	var/edit_links = "<span class='vv-edit'>\
		<a href='byond://?_src_=vars;listedit=[list_ref];index=[index]' title='Edit'>E</a>\
		<a href='byond://?_src_=vars;listchange=[list_ref];index=[index]' title='Pick the type, then edit'>C</a>\
		<a href='byond://?_src_=vars;listremove=[list_ref];index=[index]' title='Remove'>-</a>\
		</span>"
	return "<li class='vv-var' data-name='[index]'>[edit_links]<span class='vv-body'><span class='vv-index'>[index]</span> [entry]</span></li>"

/// How a list key or var name is shown. Datums, clients and lists become links to their own VV
/proc/debug_variable_key(key, sanitize = TRUE)
	if(isdatum(key))
		var/datum/datum_key = key
		return "<a href='byond://?_src_=vars;Vars=[datum_key.UID()]'>[VV_HTML_ENCODE(datum_key)] \ref[datum_key]</a>"
	if(isclient(key))
		var/client/client_key = key
		return "<a href='byond://?_src_=vars;Vars=[client_key.UID()]'>[VV_HTML_ENCODE(client_key)] \ref[client_key]</a> ([client_key] [client_key.type])"
	if(islist(key))
		var/list/list_key = key
		return "<a href='byond://?_src_=vars;VarsList=\ref[list_key]'>/list ([length(list_key)]) \ref[list_key]</a>"
	if(istext(key))
		return "<span class='vv-key'>[VV_HTML_ENCODE(key)]</span>"
	return VV_HTML_ENCODE(key)

/**
 * Returns the default value of a var as text, if it's been changed from it.
 *
 * Only checks plain values like numbers, text and paths, since things like lists and datums are almost always made at runtime.
 */
/proc/vv_changed_default(datum/owner, var_name, value)
	if(!isnull(value) && !isnum(value) && !istext(value) && !ispath(value))
		return
	var/default
	try
		default = initial(owner.vars[var_name])
	catch
		return
	if(!isnull(default) && !isnum(default) && !istext(default) && !ispath(default))
		return
	if(default == value)
		return
	if(isnull(default))
		return "null"
	if(istext(default))
		return "\"[default]\""
	return "[default]"

/proc/_debug_variable_value(name, value, level, datum/owner, sanitize)

	. = "<font color='red'>DISPLAY_ERROR:</font> ([VV_HTML_ENCODE("[value]")] \ref[value])"

	if(isnull(value))
		return "<span class='value vv-null'>null</span>"

	else if(is_color_text(value))
		return SPAN_VALUE("<span class='colorbox' style='background-color: [value];'>&nbsp;</span> \"[value]\"")

	else if(istext(value))
		return "<span class='value vv-text'>\"[VV_HTML_ENCODE(value)]\"</span>"

	else if(isicon(value))
		#ifdef VARSICON
		return "/icon ([SPAN_VALUE("[value]")]) [bicon(value, use_class=0)]"
		#else
		return "/icon ([SPAN_VALUE("[value]")])"
		#endif

	else if(istype(value, /image))
		var/image/I = value
		#ifdef VARSICON
		return "<a href='byond://?_src_=vars;Vars=[I.UID()]'>[name] \ref[value]</a> /image ([SPAN_VALUE("[value]")]) [bicon(value, use_class=0)]"
		#else
		return "<a href='byond://?_src_=vars;Vars=[I.UID()]'>[name] \ref[value]</a> /image ([SPAN_VALUE("[value]")])"
		#endif

	else if(isfile(value))
		return "<span class='value vv-file'>'[value]'</span>"

	else if(istype(value, /datum))
		var/datum/D = value
		return D.debug_variable_value(sanitize)

	else if(islist(value))
		var/list/L = value
		var/list_link = "<a href='byond://?_src_=vars;VarsList=\ref[L]'>/list ([length(L)])</a>"

		// Empty, too long or too deep to show here. They can still be opened on their own
		if(!length(L) || level >= VV_MAX_LIST_DEPTH || name == "underlays" || name == "overlays" || name == "vars" || length(L) > (IS_NORMAL_LIST(L) ? 250 : 300))
			return list_link

		var/list/items = list()
		for(var/i in 1 to length(L))
			var/key = L[i]
			var/val
			if(IS_NORMAL_LIST(L) && !isnum(key))
				val = L[key]
			if(isnull(val))
				val = key
				key = i

			items += debug_variable(key, val, level + 1, sanitize = sanitize)

		return "<span class='vv-list'><span class='vv-fold' title='Fold'></span>[list_link]<ul>[items.Join()]</ul></span>"

	else if(name in GLOB.bitfields)
		return "<span class='value vv-num'>[VV_HTML_ENCODE(translate_bitfield(VV_BITFIELD, name, value))]</span>"

	else if(isnum(value))
		return "<span class='value vv-num'>[VV_HTML_ENCODE(value)]</span>"

	else if(ispath(value))
		return "<span class='value vv-path'>[VV_HTML_ENCODE(value)]</span>"

	else
		return SPAN_VALUE("[VV_HTML_ENCODE(value)]")

/datum/proc/debug_variable_value(sanitize)
	return "<a href='byond://?_src_=vars;Vars=[UID()]'>[VV_HTML_ENCODE(src)] \ref[src]</a> <span class='vv-type'>([type])</span>"

/matrix/debug_variable_value(sanitize)
	return {"<span class='value'>
			<table class='matrixbrak'><tbody><tr><td class='lbrak'>&nbsp;</td><td>
			<table class='matrix'>
			<tbody>
				<tr><td>[a]</td><td>[d]</td><td>0</td></tr>
				<tr><td>[b]</td><td>[e]</td><td>0</td></tr>
				<tr><td>[c]</td><td>[f]</td><td>1</td></tr>
			</tbody>
			</table></td><td class='rbrak'>&nbsp;</td></tr></tbody></table></span>"} //TODO link to modify_transform wrapper for all matrices

/client/proc/view_var_Topic(href, href_list, hsrc)
	//This should all be moved over to datum/admins/Topic() or something ~Carn
	if(!check_rights(R_ADMIN|R_MOD, FALSE))
		// Clients with R_VIEWRUNTIMES can still open and refresh windows, but nothing else
		if(href_list[VV_HK_PROC_CALL] && check_rights(R_PROCCALL, FALSE))
			SSuser_verbs.invoke_verb(usr, /datum/user_verb/call_proc_datum, GET_VV_TARGET)
		else if(check_rights(R_VIEWRUNTIMES, FALSE))
			view_var_Topic_view_only(href_list)
		return

	if(view_var_Topic_list(href, href_list, hsrc))  // done because you can't use UIDs with lists and I don't want to snowflake into the below check to supress warnings
		return

	// Correct and warn about any VV topic links that aren't using UIDs
	var/static/list/page_state_params = list("vv_filter", "vv_scroll", "vv_options")
	for(var/paramname in href_list)
		if(paramname in page_state_params)
			continue // Search box and scroll position from the window, not a reference
		if(findtext(href_list[paramname], "]_"))
			continue // Contains UID-specific formatting, skip it
		var/datum/D = locate(href_list[paramname])
		if(!D)
			continue
		var/datuminfo = "[D]"
		if(istype(D))
			datuminfo = datum_info_line(D)
			href_list[paramname] = D.UID()
		else if(isclient(D))
			var/client/C = D
			href_list[paramname] = C.UID()
		stack_trace("Found \\ref-based '[paramname]' param in VV topic for [datuminfo], should be UID: [href]")

	if(href_list["Vars"])
		debug_variables(locateUID(href_list["Vars"]))

	var/target = GET_VV_TARGET
	vv_core_topics(target, href_list, href)
	if(isdatum(target))
		var/datum/D = target
		D.vv_do_topic(href_list)

	// Refresh the VV if something asked us to
	if(href_list["datumrefresh"])
		var/datum/DAT = locateUID(href_list["datumrefresh"])
		if(!istype(DAT, /datum) && !isclient(DAT))
			return
		src.debug_variables(DAT, href_list)

/// The only VV links that work for clients with just R_VIEWRUNTIMES
/client/proc/view_var_Topic_view_only(href_list)
	if(href_list["Vars"])
		debug_variables(locateUID(href_list["Vars"]))
	else if(href_list["datumrefresh"])
		debug_variables(locateUID(href_list["datumrefresh"]), href_list)
	else if(href_list["VarsList"])
		debug_variables(locate(href_list["VarsList"]))
	else if(href_list["listrefresh"])
		debug_variables(locate(href_list["listrefresh"]), href_list)

/client/proc/view_var_Topic_list(href, href_list, hsrc)
	if(href_list["VarsList"])
		debug_variables(locate(href_list["VarsList"]))
		return TRUE

	if(href_list["listrefresh"])
		debug_variables(locate(href_list["listrefresh"]), href_list)
		return TRUE

	// Everything below edits a list
	var/static/list/list_edit_links = list("listedit", "listchange", "listremove", "listadd", "listdupes", "listnulls", "listlen", "listshuffle")
	var/action
	for(var/edit_link in list_edit_links)
		if(href_list[edit_link])
			action = edit_link
			break
	if(!action)
		return FALSE

	if(!check_rights(R_VAREDIT))
		return TRUE

	var/list/L = locate(href_list[action])
	if(!istype(L))
		to_chat(usr, "This can only be used on instances of type /list")
		return TRUE

	// Entry buttons go by position, so make sure the entry is still there
	var/index
	if(action == "listedit" || action == "listchange" || action == "listremove")
		index = text2num(href_list["index"])
		if(!index || index > length(L))
			to_chat(usr, SPAN_WARNING("That entry isn't in the list anymore."))
			debug_variables(L, href_list)
			return TRUE

	switch(action)
		if("listedit")
			mod_list(L, null, "list", "contents", index, autodetect_class = TRUE)

		if("listchange")
			mod_list(L, null, "list", "contents", index, autodetect_class = FALSE)

		if("listremove")
			var/variable = L[index]
			var/prompt = alert("Do you want to remove entry [index] ([variable]) from the list?", "Confirm", "Yes", "No")
			if(prompt != "Yes")
				return TRUE
			// The list can change while the prompt is open
			if(index > length(L) || L[index] != variable)
				to_chat(usr, SPAN_WARNING("The list changed, nothing was removed."))
				debug_variables(L, href_list)
				return TRUE
			L.Cut(index, index+1)
			log_world("### ListVarEdit by [src]: /list's contents: REMOVED=[html_encode("[variable]")]")
			log_admin("[key_name(src)] modified list's contents: REMOVED=[variable]")
			message_admins("[key_name_admin(src)] modified list's contents: REMOVED=[variable]")

		if("listadd")
			mod_list_add(L, null, "list", "contents")

		if("listdupes")
			uniqueList_inplace(L)
			log_world("### ListVarEdit by [src]: /list contents: CLEAR DUPES")
			log_admin("[key_name(src)] modified list's contents: CLEAR DUPES")
			message_admins("[key_name_admin(src)] modified list's contents: CLEAR DUPES")

		if("listnulls")
			listclearnulls(L)
			log_world("### ListVarEdit by [src]: /list contents: CLEAR NULLS")
			log_admin("[key_name(src)] modified list's contents: CLEAR NULLS")
			message_admins("[key_name_admin(src)] modified list's contents: CLEAR NULLS")

		if("listlen")
			var/value = vv_get_value(VV_NUM)
			if(value["class"] != VV_NUM)
				return TRUE

			L.len = max(0, value["value"])
			log_world("### ListVarEdit by [src]: /list len: [length(L)]")
			log_admin("[key_name(src)] modified list's len: [length(L)]")
			message_admins("[key_name_admin(src)] modified list's len: [length(L)]")

		if("listshuffle")
			shuffle_inplace(L)
			log_world("### ListVarEdit by [src]: /list contents: SHUFFLE")
			log_admin("[key_name(src)] modified list's contents: SHUFFLE")
			message_admins("[key_name_admin(src)] modified list's contents: SHUFFLE")

	// Show the change
	debug_variables(L, href_list)
	return TRUE

USER_VERB(debug_global_variables, R_ADMIN|R_VIEWRUNTIMES, "Debug Global Variables", "Debug Global Variables", VERB_CATEGORY_DEBUG, var_search as text)
	var_search = trim(var_search)
	if(!var_search)
		return
	if(!GLOB.can_vv_get(var_search))
		return
	switch(var_search)
		if("vars")
			return FALSE
	if(!(var_search in GLOB.vars))
		to_chat(client, SPAN_DEBUG("GLOB.[var_search] does not exist."))
		return
	log_and_message_admins("is debugging the Global Variables controller with the search term \"[var_search]\"")
	var/result = GLOB.vars[var_search]
	if(islist(result) || isclient(result) || istype(result, /datum))
		to_chat(client, SPAN_DEBUG("Now showing GLOB.[var_search]."))
		return client.debug_variables(result)
	to_chat(client, SPAN_DEBUG("GLOB.[var_search] returned [result]."))

#undef VV_HTML_ENCODE
#undef VV_MAX_LIST_DEPTH
