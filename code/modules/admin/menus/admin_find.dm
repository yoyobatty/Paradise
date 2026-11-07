// Find: search the whole world for things by name, type, ref or player, in one window.
// It can look everywhere, on your z-level, near you, or on one tile, where it lists everything there: the turf, its area,
// and every atom on it, including invisible and under-floor ones, and what's inside them if asked.
// Each result says where it is and who's carrying it, with buttons to VV, jump, follow, bring, mark or delete it.

/// How many results are sent to the window. The count still includes the rest
#define FIND_SHOWN 300

/// Each admin's Find window, so their searches don't mix
/client/var/datum/admin_find/admin_find

USER_VERB(admin_find, R_ADMIN, "Find", "Find things by name, type, ref or player, anywhere or on one tile.", VERB_CATEGORY_ADMIN)
	client.open_admin_find()

/client/proc/open_admin_find(turf/tile)
	if(!admin_find)
		admin_find = new
	if(tile)
		admin_find.look_at_tile(tile, mob)
	admin_find.ui_interact(mob)

/datum/admin_find
	/// What the query is: name, type, ref or player
	var/mode = "name"
	var/query = ""
	/// Where to look: everywhere, z, near or tile
	var/scope = "everywhere"
	var/radius = 15
	var/tile_x
	var/tile_y
	var/tile_z
	/// On a tile, whether to list what's inside things there too, like a backpack's contents
	var/inside = FALSE
	/// UIDs of the results shown
	var/list/results = list()
	/// How many of each type matched
	var/list/type_counts = list()
	var/matched = 0
	var/searched = FALSE
	/// How long the last search took, in seconds
	var/took = 0

/datum/admin_find/ui_state(mob/user)
	return GLOB.admin_state

/datum/admin_find/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "AdminFind", "Find")
		ui.set_autoupdate(FALSE)
		ui.open()

/datum/admin_find/proc/look_at_tile(turf/T, mob/user)
	scope = "tile"
	tile_x = T.x
	tile_y = T.y
	tile_z = T.z
	mode = "name"
	query = ""
	search(user)

/// Whether something is where the search is looking
/datum/admin_find/proc/in_scope(atom/A, turf/here)
	switch(scope)
		if("z")
			var/turf/T = get_turf(A)
			return T && here && T.z == here.z
		if("near")
			var/turf/T = get_turf(A)
			return T && here && T.z == here.z && get_dist(T, here) <= radius
	return TRUE

/datum/admin_find/proc/matches(datum/D, typepath, needle)
	switch(mode)
		if("name")
			if(!needle)
				return TRUE
			if(!isatom(D))
				return FALSE
			var/atom/A = D
			return findtext(A.name, needle)
		if("type")
			return istype(D, typepath)
		if("player")
			if(!ismob(D))
				return FALSE
			var/mob/M = D
			return M.ckey && findtext(M.ckey, ckey(needle))
	return FALSE

/datum/admin_find/proc/search(mob/user)
	var/started = REALTIMEOFDAY
	results = list()
	type_counts = list()
	matched = 0
	searched = TRUE
	var/turf/here = get_turf(user)
	var/needle = trim(query)
	var/list/found = list()
	if(mode == "ref")
		var/datum/D = locateUID(needle) || locate(needle)
		if(!D && !findtext(needle, "\["))
			D = locate("\[[needle]\]")
		if(isdatum(D))
			found += D
	else if(scope == "tile")
		var/turf/T = locate(tile_x, tile_y, tile_z)
		if(T)
			var/typepath = mode == "type" ? text2path(needle) : null
			var/list/everything = list(T, T.loc)
			for(var/atom/movable/AM as anything in T.contents)
				everything += AM
				if(inside)
					everything += AM.GetAllContents() - AM
			for(var/datum/D as anything in everything)
				if(matches(D, typepath, needle))
					found += D
	else
		var/typepath = mode == "type" ? text2path(needle) : null
		if(mode == "type" && !typepath)
			took = 0
			return
		var/count = 0
		if(mode == "player")
			for(var/mob/M as anything in GLOB.mob_list)
				if(matches(M, null, needle) && in_scope(M, here))
					found += M
		else if(ispath(typepath, /turf))
			for(var/turf/T in world)
				if(istype(T, typepath) && in_scope(T, here))
					found += T
				if(!(++count % 5000))
					CHECK_TICK
		else if(ispath(typepath, /area))
			for(var/area/A in world)
				if(istype(A, typepath))
					found += A
		else if(typepath && !ispath(typepath, /atom))
			// Every datum in the world, which is slow, so only for types that aren't atoms
			for(var/datum/D)
				if(istype(D, typepath))
					found += D
				if(!(++count % 5000))
					CHECK_TICK
		else
			for(var/atom/movable/AM in world)
				if(matches(AM, typepath, needle) && in_scope(AM, here))
					found += AM
				if(!(++count % 5000))
					CHECK_TICK
	matched = length(found)
	for(var/datum/D as anything in found)
		type_counts["[D.type]"]++
		if(length(results) < FIND_SHOWN)
			results += D.UID()
	took = round((REALTIMEOFDAY - started) / 10, 0.01)

/// One result as the window shows it
/proc/admin_find_row(datum/D)
	var/list/row = list("uid" = D.UID(), "type" = "[D.type]", "name" = "[D]")
	if(isatom(D))
		var/atom/A = D
		row["name"] = A.name
		var/turf/T = get_turf(A)
		if(T)
			var/area/turf_area = T.loc
			row["where"] = "[turf_area?.name] ([T.x], [T.y], [T.z])"
		else if(!isarea(A))
			row["where"] = "nullspace"
		row["movable"] = ismovable(A)
		row["invisible"] = A.invisibility > SEE_INVISIBLE_LIVING || !A.icon
		// Pipes, cables and such that go under floor tiles
		row["underfloor"] = ismovable(A) && A.level == 1
		var/atom/container = A.loc
		var/steps = 0
		while(container && !isturf(container) && steps++ < 20)
			if(ismob(container))
				var/mob/carrier = container
				row["carrier"] = "[carrier.name][carrier.ckey ? " ([carrier.ckey])" : ""]"
				break
			container = container.loc
		if(ismob(A))
			var/mob/M = A
			row["ckey"] = M.ckey
	return row

/datum/admin_find/ui_data(mob/user)
	var/list/rows = list()
	for(var/uid in results)
		var/datum/D = locateUID(uid)
		if(D && !QDELETED(D))
			rows += list(admin_find_row(D))
	var/list/counts = list()
	var/list/sorted = sortTim(type_counts.Copy(), GLOBAL_PROC_REF(cmp_numeric_dsc), associative = TRUE)
	for(var/type in sorted)
		counts += list(list("type" = type, "count" = sorted[type]))
		if(length(counts) >= 12)
			break
	var/turf/here = get_turf(user)
	return list(
		"mode" = mode,
		"query" = query,
		"scope" = scope,
		"radius" = radius,
		"tile" = tile_z ? "[tile_x], [tile_y], [tile_z]" : null,
		"here" = here ? "[here.x], [here.y], [here.z]" : null,
		"inside" = inside,
		"rows" = rows,
		"counts" = counts,
		"matched" = matched,
		"searched" = searched,
		"took" = took,
	)

/datum/admin_find/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	if(..())
		return
	var/mob/user = ui.user
	if(!check_rights(R_ADMIN, user = user))
		return
	switch(action)
		if("search")
			mode = (params["mode"] in list("name", "type", "ref", "player")) ? params["mode"] : "name"
			query = params["query"] || ""
			scope = (params["scope"] in list("everywhere", "z", "near", "tile")) ? params["scope"] : "everywhere"
			radius = clamp(text2num(params["radius"]) || 15, 1, 100)
			if(scope == "tile")
				var/list/xyz = splittext(params["tile"] || "", ",")
				if(length(xyz) == 3)
					tile_x = text2num(xyz[1])
					tile_y = text2num(xyz[2])
					tile_z = text2num(xyz[3])
			inside = text2num(params["inside"]) ? TRUE : FALSE
			search(user)
			return TRUE
		if("here")
			var/turf/T = get_turf(user)
			if(T)
				look_at_tile(T, user)
			return TRUE
	var/datum/D = locateUID(params["uid"])
	if(!isdatum(D))
		return
	var/client/C = user.client
	switch(action)
		if("vv")
			C.debug_variables(D)
		if("jmp")
			var/turf/T = get_turf(D)
			if(T)
				SSuser_verbs.invoke_verb(C, /datum/user_verb/jump_to_turf, T)
		if("flw")
			if(!ismovable(D))
				return
			if(!isobserver(user))
				SSuser_verbs.invoke_verb(C, /datum/user_verb/admin_ghost)
			var/mob/dead/observer/ghost = C.mob
			if(istype(ghost))
				ghost.manual_follow(D)
		if("get")
			if(ismovable(D) && !QDELETED(D))
				var/atom/movable/AM = D
				AM.forceMove(get_turf(user))
				log_admin("[key_name(user)] brought [AM] ([AM.type]) to [COORD(user)] with Find")
		if("mark")
			C.holder.marked_datum = D
			to_chat(user, SPAN_NOTICE("Marked [D]."))
		if("tile")
			var/turf/T = get_turf(D)
			if(T)
				look_at_tile(T, user)
		if("del")
			// admin_delete() asks if they're sure
			C.admin_delete(D)
			search(user)
	return TRUE

/atom/vv_get_dropdown()
	. = ..()
	if(get_turf(src))
		VV_DROPDOWN_OPTION(VV_HK_FIND_ON_TILE, "Find everything on this tile")

/atom/vv_do_topic(list/href_list)
	. = ..()
	// Find only needs R_ADMIN, not the R_VAREDIT the other options need
	if(href_list[VV_HK_FIND_ON_TILE] && check_rights(R_ADMIN))
		var/turf/T = get_turf(src)
		if(T)
			usr.client.open_admin_find(T)

#undef FIND_SHOWN
