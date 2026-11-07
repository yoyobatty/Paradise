// The Bans window: making a ban, finding and lifting bans, and a player's notes and watchlist entry, all in one tgui window.
// It goes through the same procs as the old panels (DB_ban_record(), DB_ban_unban_by_id(), DB_ban_edit(), add_note() and the
// watchlist procs), so a ban made here works the same as one made from the player panel.

#define BAN_SEARCH_LIMIT 100

/// Each admin's Bans window, so their forms and searches don't mix
/client/var/datum/ban_window/ban_window

/// Opens the Bans window. target_ckey fills in the player, and roles picks the role grid instead of a server ban
/client/proc/open_ban_window(tab = "new", target_ckey, roles = FALSE)
	if(!check_rights(R_BAN))
		return
	if(!SSdbcore.IsConnected())
		to_chat(src, SPAN_WARNING("Bans need the database, and it isn't connected."))
		return
	if(!ban_window)
		ban_window = new
	ban_window.tab = tab
	if(target_ckey)
		ban_window.set_target(target_ckey)
		ban_window.kind = roles ? "roles" : "server"
		ban_window.notes_ckey = ckey(target_ckey)
		ban_window.load_notes()
	ban_window.ui_interact(mob)

/datum/ban_window
	/// new, bans or notes
	var/tab = "new"
	/// A line saying what the last button did
	var/notice
	var/notice_good = TRUE

	// The New ban form
	var/target_ckey = ""
	var/target_ip = ""
	var/target_cid = ""
	var/match_ip = TRUE
	var/match_cid = TRUE
	var/length_amount = 1
	/// minutes, hours, days, weeks, months or perma
	var/length_unit = "days"
	/// server, roles or admin
	var/kind = "server"
	var/list/picked_roles = list()
	var/reason = ""
	/// The player's bans, notes, watchlist entry, IPs and possible alts, for beside the form
	var/list/record

	// The Bans tab
	var/search_text = ""
	var/search_ckey = ""
	var/search_admin = ""
	/// active, expired, lifted or all
	var/search_status = "active"
	/// all, server or roles
	var/search_kind = "all"
	var/list/search_results = list()
	var/searched = FALSE

	// The Notes tab
	var/notes_ckey = ""
	var/list/notes = list()
	var/list/watch

/datum/ban_window/ui_state(mob/user)
	return GLOB.admin_state

/datum/ban_window/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "BanWindow", "Bans")
		ui.set_autoupdate(FALSE)
		ui.open()

/// The role grid, grouped like the old Job-Ban Panel. Picking a group picks all its roles
/datum/ban_window/ui_static_data(mob/user)
	var/list/groups = list()
	groups += list(ban_window_group("Command", GLOB.command_positions))
	groups += list(ban_window_group("Security", GLOB.security_positions))
	groups += list(ban_window_group("Engineering", GLOB.engineering_positions))
	groups += list(ban_window_group("Medical", GLOB.medical_positions))
	groups += list(ban_window_group("Science", GLOB.science_positions))
	groups += list(ban_window_group("Service", GLOB.service_positions))
	groups += list(ban_window_group("Supply", GLOB.supply_positions))
	groups += list(ban_window_group("Non-human", GLOB.nonhuman_positions, list("Drone", "pAI", ROLE_GOLEM)))
	groups += list(list("name" = "Antagonists", "roles" = list("Syndicate") + GLOB.antag_roles))
	groups += list(list("name" = "Other", "roles" = GLOB.other_roles.Copy()))
	return list("groups" = groups)

/// A department's jobs by title, plus any extra roles
/proc/ban_window_group(name, list/positions, list/extra)
	var/list/roles = list()
	for(var/position in positions)
		var/datum/job/job = SSjobs.GetJob(position)
		if(job)
			roles |= job.title
	if(extra)
		roles |= extra
	return list("name" = name, "roles" = roles)

/datum/ban_window/ui_data(mob/user)
	var/list/players = list()
	for(var/client/C in GLOB.clients)
		players += list(list("ckey" = C.ckey, "name" = C.mob?.real_name || C.mob?.name, "online" = TRUE))
	// Players who left this round, so they can still be banned with their IP and computer ID
	for(var/mob/M in GLOB.mob_list)
		if(M.last_known_ckey && !M.client && !GLOB.directory[M.last_known_ckey] && !isnewplayer(M))
			players += list(list("ckey" = M.last_known_ckey, "name" = M.real_name || M.name, "online" = FALSE))
	return list(
		"tab" = tab,
		"notice" = notice,
		"notice_good" = notice_good,
		"players" = players,
		"target_ckey" = target_ckey,
		"target_ip" = target_ip,
		"target_cid" = target_cid,
		"match_ip" = match_ip,
		"match_cid" = match_cid,
		"length_amount" = length_amount,
		"length_unit" = length_unit,
		"ends" = ban_window_ends(),
		"kind" = kind,
		"picked_roles" = picked_roles,
		"reason" = reason,
		"record" = record,
		"search_text" = search_text,
		"search_ckey" = search_ckey,
		"search_admin" = search_admin,
		"search_status" = search_status,
		"search_kind" = search_kind,
		"search_results" = search_results,
		"searched" = searched,
		"notes_ckey" = notes_ckey,
		"notes" = notes,
		"watch" = watch,
	)

/// How many minutes the form's length is, or -1 for a permanent ban
/datum/ban_window/proc/ban_window_minutes()
	switch(length_unit)
		if("perma")
			return -1
		if("hours")
			return round(length_amount * 60)
		if("days")
			return round(length_amount * 1440)
		if("weeks")
			return round(length_amount * 10080)
		if("months")
			return round(length_amount * 43200)
	return round(length_amount)

/// When the ban would end, as text for under the length
/datum/ban_window/proc/ban_window_ends()
	var/minutes = ban_window_minutes()
	if(minutes < 0)
		return "Never, it must be appealed"
	if(minutes < 1)
		return "Pick a length"
	// world.realtime is in deciseconds
	return "Ends [time2text(world.realtime + minutes * 600, "DDD DD Month YYYY, hh:mm")] (server time)"

/// Fills in the form's player, with their IP and computer ID from this round if they were here, or else the database
/datum/ban_window/proc/set_target(new_ckey)
	target_ckey = ckey(new_ckey)
	target_ip = ""
	target_cid = ""
	picked_roles = list()
	var/client/C = GLOB.directory[target_ckey]
	if(C)
		target_ip = C.address
		target_cid = C.computer_id
	else
		for(var/mob/M in GLOB.mob_list)
			if(M.last_known_ckey == target_ckey)
				target_ip = M.lastKnownIP
				target_cid = M.computer_id
				break
	load_record()
	if(record && (!target_ip || !target_cid))
		target_ip = target_ip || record["last_ip"]
		target_cid = target_cid || record["last_cid"]

/// Loads what's known about the form's player from the database
/datum/ban_window/proc/load_record()
	record = null
	if(!target_ckey)
		return
	var/list/new_record = list("ckey" = target_ckey, "found" = FALSE, "bans" = list(), "notes" = list(), "ips" = list(), "cids" = list(), "alts" = list())
	var/datum/db_query/query = SSdbcore.NewQuery("SELECT firstseen, lastseen, ip, computerid FROM player WHERE ckey=:ckey", list("ckey" = target_ckey))
	if(!query.warn_execute())
		qdel(query)
		return
	if(query.NextRow())
		new_record["found"] = TRUE
		new_record["firstseen"] = query.item[1]
		new_record["lastseen"] = query.item[2]
		new_record["last_ip"] = query.item[3]
		new_record["last_cid"] = query.item[4]
	qdel(query)

	// The IPs and computer IDs they connected from recently
	query = SSdbcore.NewQuery("SELECT DISTINCT INET_NTOA(ip), computerid FROM connection_log WHERE ckey=:ckey ORDER BY id DESC LIMIT 30", list("ckey" = target_ckey))
	if(query.warn_execute())
		var/list/ips = new_record["ips"]
		var/list/cids = new_record["cids"]
		while(query.NextRow())
			ips |= query.item[1]
			cids |= query.item[2]
	qdel(query)

	// Other players last seen on the same IP or computer
	if(new_record["found"])
		query = SSdbcore.NewQuery("SELECT ckey, ip=:ip, computerid=:cid FROM player WHERE (ip=:ip OR computerid=:cid) AND ckey!=:ckey LIMIT 20", list(
			"ip" = new_record["last_ip"],
			"cid" = new_record["last_cid"],
			"ckey" = target_ckey,
		))
		if(query.warn_execute())
			var/list/alts = new_record["alts"]
			while(query.NextRow())
				alts += list(list("ckey" = query.item[1], "same_ip" = text2num(query.item[2]) ? TRUE : FALSE, "same_cid" = text2num(query.item[3]) ? TRUE : FALSE))
		qdel(query)

	new_record["bans"] = ban_window_query_bans("ckey=:ckey", list("ckey" = target_ckey), 30)

	query = SSdbcore.NewQuery("SELECT id, notetext, timestamp, adminckey, public FROM notes WHERE ckey=:ckey AND deleted=0 ORDER BY timestamp DESC LIMIT 10", list("ckey" = target_ckey))
	if(query.warn_execute())
		var/list/record_notes = new_record["notes"]
		while(query.NextRow())
			record_notes += list(list("id" = query.item[1], "text" = html_decode(query.item[2]), "time" = query.item[3], "admin" = query.item[4], "public" = text2num(query.item[5]) ? TRUE : FALSE))
	qdel(query)

	query = SSdbcore.NewQuery("SELECT reason, adminckey, timestamp FROM watch WHERE ckey=:ckey", list("ckey" = target_ckey))
	if(query.warn_execute() && query.NextRow())
		new_record["watch"] = list("reason" = query.item[1], "admin" = query.item[2], "time" = query.item[3])
	qdel(query)
	record = new_record

/// Bans matching a WHERE clause, newest first, with role bans made together grouped into one entry
/proc/ban_window_query_bans(where, list/params, limit = BAN_SEARCH_LIMIT)
	. = list()
	var/datum/db_query/query = SSdbcore.NewQuery({"
		SELECT id, bantime, bantype, reason, job, duration, expiration_time, ckey, a_ckey, unbanned, unbanned_ckey, unbanned_datetime,
			IF(unbanned = 1, 'lifted', IF(bantype LIKE '%PERMA%' OR expiration_time > NOW(), 'active', 'expired')),
			TIMESTAMPDIFF(MINUTE, NOW(), expiration_time), ip, computerid, edits
		FROM ban WHERE [where] ORDER BY bantime DESC, id DESC LIMIT [limit]
	"}, params)
	if(!query.warn_execute())
		qdel(query)
		return
	var/list/groups = list()
	while(query.NextRow())
		var/bantype = query.item[3]
		var/is_role = findtext(bantype, "JOB")
		var/group_key = "[query.item[8]]|[query.item[9]]|[query.item[2]]|[bantype]|[query.item[4]]"
		var/list/entry = is_role ? groups[group_key] : null
		if(!entry)
			entry = list(
				"ids" = list(),
				"bantime" = query.item[2],
				"bantype" = bantype,
				"kind" = is_role ? "roles" : (findtext(bantype, "ADMIN") ? "admin" : "server"),
				"perma" = findtext(bantype, "PERMA") ? TRUE : FALSE,
				"reason" = query.item[4],
				"roles" = list(),
				"duration" = text2num(query.item[6]),
				"expires" = query.item[7],
				"ckey" = query.item[8],
				"admin" = query.item[9],
				"lifted_by" = query.item[11],
				"lifted_at" = query.item[12],
				"status" = query.item[13],
				"minutes_left" = text2num(query.item[14]),
				"ip" = query.item[15],
				"cid" = query.item[16],
				"edits" = query.item[17],
			)
			if(is_role)
				groups[group_key] = entry
			. += list(entry)
		var/list/ids = entry["ids"]
		ids += text2num(query.item[1])
		if(is_role)
			var/list/roles = entry["roles"]
			roles += query.item[5]
	qdel(query)

/// Runs the Bans tab's search
/datum/ban_window/proc/search_bans()
	var/list/where = list("1=1")
	var/list/params = list()
	if(search_ckey)
		where += "ckey LIKE :ckey"
		params["ckey"] = "%[ckey(search_ckey)]%"
	if(search_admin)
		where += "a_ckey LIKE :admin"
		params["admin"] = "%[ckey(search_admin)]%"
	if(search_text)
		// Words match the reason, a role, an IP or a computer ID
		where += "(reason LIKE :text OR job LIKE :text OR ip LIKE :text OR computerid LIKE :text)"
		params["text"] = "%[search_text]%"
	switch(search_status)
		if("active")
			where += "unbanned IS NULL AND (bantype LIKE '%PERMA%' OR expiration_time > NOW())"
		if("expired")
			where += "unbanned IS NULL AND bantype NOT LIKE '%PERMA%' AND expiration_time <= NOW()"
		if("lifted")
			where += "unbanned = 1"
	switch(search_kind)
		if("server")
			where += "bantype NOT LIKE '%JOB%'"
		if("roles")
			where += "bantype LIKE '%JOB%'"
	search_results = ban_window_query_bans(where.Join(" AND "), params)
	// Active bans that end soonest come first, and permanent ones after them
	if(search_status == "active")
		search_results = sortTim(search_results, GLOBAL_PROC_REF(cmp_ban_window_ends))
	searched = TRUE

/proc/cmp_ban_window_ends(list/a, list/b)
	var/a_left = a["perma"] ? INFINITY : a["minutes_left"]
	var/b_left = b["perma"] ? INFINITY : b["minutes_left"]
	return a_left - b_left

/// Loads the Notes tab's player
/datum/ban_window/proc/load_notes()
	notes = list()
	watch = null
	if(!notes_ckey)
		return
	var/datum/db_query/query = SSdbcore.NewQuery("SELECT id, notetext, timestamp, adminckey, last_editor, public, automated FROM notes WHERE ckey=:ckey AND deleted=0 ORDER BY timestamp DESC", list("ckey" = notes_ckey))
	if(query.warn_execute())
		while(query.NextRow())
			notes += list(list("id" = text2num(query.item[1]), "text" = html_decode(query.item[2]), "time" = query.item[3], "admin" = query.item[4], "editor" = query.item[5], "public" = text2num(query.item[6]) ? TRUE : FALSE, "automated" = text2num(query.item[7]) ? TRUE : FALSE))
	qdel(query)
	query = SSdbcore.NewQuery("SELECT reason, adminckey, timestamp, last_editor FROM watch WHERE ckey=:ckey", list("ckey" = notes_ckey))
	if(query.warn_execute() && query.NextRow())
		watch = list("reason" = query.item[1], "admin" = query.item[2], "time" = query.item[3], "editor" = query.item[4])
	qdel(query)

/datum/ban_window/proc/say(text, good = TRUE)
	notice = text
	notice_good = good

/datum/ban_window/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	if(..())
		return
	var/mob/user = ui.user
	if(!check_rights(R_BAN, user = user))
		return
	var/datum/admins/holder = user.client.holder
	switch(action)
		if("tab")
			if(params["tab"] in list("new", "bans", "notes"))
				tab = params["tab"]
				notice = null
				if(tab == "bans" && !searched)
					search_bans()
			return TRUE

		// New ban
		if("set_target")
			set_target(params["ckey"])
			notice = null
			return TRUE
		if("set_form")
			notice = null
			if(!isnull(params["match_ip"]))
				match_ip = text2num(params["match_ip"]) ? TRUE : FALSE
			if(!isnull(params["match_cid"]))
				match_cid = text2num(params["match_cid"]) ? TRUE : FALSE
			if(!isnull(params["ip"]))
				target_ip = trim(params["ip"])
			if(!isnull(params["cid"]))
				target_cid = trim(params["cid"])
			if(!isnull(params["amount"]))
				length_amount = max(0, text2num(params["amount"]) || 0)
			if(params["unit"] in list("minutes", "hours", "days", "weeks", "months", "perma"))
				length_unit = params["unit"]
			if(params["kind"] in list("server", "roles", "admin"))
				kind = params["kind"]
			if(!isnull(params["reason"]))
				reason = params["reason"]
			return TRUE
		if("toggle_roles")
			var/list/roles = params["roles"]
			if(!islist(roles))
				return
			var/on = text2num(params["on"])
			for(var/role in roles)
				if(on)
					picked_roles |= role
				else
					picked_roles -= role
			return TRUE
		if("ban")
			if(!isnull(params["reason"]))
				reason = params["reason"]
			make_ban(user, holder)
			return TRUE

		// Bans list
		if("search")
			search_text = trim(params["text"] || "")
			search_ckey = trim(params["ckey"] || "")
			search_admin = trim(params["admin"] || "")
			if(params["status"] in list("active", "expired", "lifted", "all"))
				search_status = params["status"]
			if(params["kind"] in list("all", "server", "roles"))
				search_kind = params["kind"]
			search_bans()
			return TRUE
		if("lift")
			var/list/ids = params["ids"]
			if(!islist(ids))
				return
			var/lifted = 0
			for(var/id in ids)
				if(isnum(id))
					holder.DB_ban_unban_by_id(id)
					lifted++
			say("Lifted [lifted] ban[lifted == 1 ? "" : "s"].")
			ban_window_refresh()
			return TRUE
		if("edit")
			var/list/ids = params["ids"]
			if(!islist(ids))
				return
			var/new_reason = trim(params["reason"] || "")
			var/new_minutes = text2num(params["minutes"])
			for(var/id in ids)
				if(!isnum(id))
					continue
				if(new_reason)
					holder.DB_ban_edit(id, "reason", new_reason)
				if(new_minutes > 0)
					holder.DB_ban_edit(id, "duration", round(new_minutes))
			say("Edited the ban.")
			ban_window_refresh()
			return TRUE

		// Notes and watchlist
		if("notes_for")
			notes_ckey = ckey(params["ckey"])
			load_notes()
			return TRUE
		if("add_note")
			var/text = trim(params["text"] || "")
			if(!notes_ckey || !text)
				return
			add_note(notes_ckey, text, null, user.ckey, TRUE, TRUE, FALSE, public = text2num(params["public"]) ? TRUE : FALSE)
			say("Added a note for [notes_ckey].")
			ban_window_refresh()
			return TRUE
		if("edit_note")
			var/text = trim(params["text"] || "")
			if(text)
				edit_note(text2num(params["id"]), text)
				ban_window_refresh()
			return TRUE
		if("delete_note")
			remove_note(text2num(params["id"]))
			say("Deleted the note.")
			ban_window_refresh()
			return TRUE
		if("note_public")
			toggle_note_publicity(text2num(params["id"]), TRUE)
			ban_window_refresh()
			return TRUE
		if("watch_set")
			var/text = trim(params["text"] || "")
			if(!notes_ckey || !text)
				return
			if(watch)
				user.client.watchlist_edit(notes_ckey, 0, text)
			else
				user.client.watchlist_add(notes_ckey, 0, text)
			ban_window_refresh()
			return TRUE
		if("watch_remove")
			if(notes_ckey)
				user.client.watchlist_remove(notes_ckey)
			ban_window_refresh()
			return TRUE

/// Loads everything shown again after a change
/datum/ban_window/proc/ban_window_refresh()
	load_record()
	load_notes()
	if(searched)
		search_bans()

/// Makes the ban the form describes, with the same note, messages and kick as the player panel's Ban and Jobban
/datum/ban_window/proc/make_ban(mob/user, datum/admins/holder)
	var/minutes = ban_window_minutes()
	var/perma = minutes < 0
	var/ban_reason = trim(reason)
	if(!target_ckey)
		say("Pick a player first.", FALSE)
		return
	if(!ban_reason)
		say("Write a reason.", FALSE)
		return
	if(!perma && minutes < 1)
		say("Pick a length.", FALSE)
		return
	if(kind == "roles" && !length(picked_roles))
		say("Pick at least one role.", FALSE)
		return
	if(!perma)
		// The same cap as the player panel: just under a year
		minutes = min(minutes, 525599)
	var/ip = match_ip ? target_ip : ""
	var/cid = match_cid ? target_cid : ""
	var/client/target_client = GLOB.directory[target_ckey]
	var/length_text = perma ? "permanently" : "for [minutes] minutes"

	if(kind == "roles")
		var/list/already = list()
		for(var/list/ban in record?["bans"])
			if(ban["status"] == "active" && ban["kind"] == "roles")
				already |= ban["roles"]
		var/list/banned_from = list()
		for(var/role in picked_roles)
			if(role in already)
				continue
			if(!holder.DB_ban_record(perma ? BANTYPE_JOB_PERMA : BANTYPE_JOB_TEMP, null, minutes, ban_reason, role, 0, target_ckey, ip, cid))
				continue
			banned_from += role
			log_admin("[key_name(user)] [perma ? "perma" : "temp"]-jobbanned [target_ckey] from [role][perma ? "" : " for [minutes] minutes"]")
		if(!length(banned_from))
			say("No role bans were made. They may already be banned from those, or the database refused it (see chat).", FALSE)
			return
		var/role_text = english_list(banned_from)
		add_note(target_ckey, "Banned from [role_text] - [ban_reason]", null, user.ckey, 0, public = TRUE)
		message_admins(SPAN_NOTICE("[key_name_admin(user)] banned [target_ckey] from [role_text] [length_text]"))
		if(target_client)
			target_client.jbh.reload_jobbans(target_client)
			to_chat(target_client, SPAN_WARNING("<big><b>You have been jobbanned by [user.ckey] from: [role_text].</b></big>"))
			to_chat(target_client, SPAN_DANGER("The reason is: [ban_reason]"))
			to_chat(target_client, SPAN_WARNING(perma ? "This jobban can be lifted only on appeal." : "This jobban will be lifted in [minutes] minutes."))
		say("Banned [target_ckey] from [role_text] [length_text].")
	else
		var/bantype
		if(kind == "admin")
			bantype = perma ? BANTYPE_ADMIN_PERMA : BANTYPE_ADMIN_TEMP
		else
			bantype = perma ? BANTYPE_PERMA : BANTYPE_TEMP
		if(!holder.DB_ban_record(bantype, null, minutes, ban_reason, "", 0, target_ckey, ip, cid))
			say("The ban wasn't made. See chat for why.", FALSE)
			return
		add_note(target_ckey, perma ? "Permanently banned - [ban_reason]" : "Banned for [minutes] minutes - [ban_reason]", null, user.ckey, FALSE)
		log_admin("[key_name(user)] has banned [target_ckey] [length_text].\nReason: [ban_reason]")
		message_admins(SPAN_NOTICE("[key_name_admin(user)] has banned [target_ckey] [length_text].\nReason: [ban_reason]"))
		if(target_client)
			to_chat(target_client, SPAN_WARNING("<big><b>You have been banned by [user.ckey].\nReason: [ban_reason].</b></big>"))
			to_chat(target_client, SPAN_WARNING(perma ? "This ban does not expire automatically and must be appealed." : "This is a temporary ban, it will be removed in [minutes] minutes."))
			if(GLOB.configuration.url.banappeals_url)
				to_chat(target_client, SPAN_WARNING("To try to resolve this matter head to [GLOB.configuration.url.banappeals_url]"))
			qdel(target_client)
		say("Banned [target_ckey] from the server [length_text].")
	reason = ""
	picked_roles = list()
	ban_window_refresh()

#undef BAN_SEARCH_LIMIT
