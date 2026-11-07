// View Variables shows a datum's internals, the parts the var list only shows as raw lists: its components, the signals it
// listens to and who listens to its signals, its timers, its traits and where they came from, its status effects, which
// subsystems are processing it, and whether it's been deleted. It's a folded section with a count of each on its first line,
// and it stays open or shut the way the admin last left it.

/// A VV link to D, or "null"
/proc/vv_internals_link(datum/D, text)
	if(!isdatum(D))
		return "null"
	return ADMIN_VV(D, html_encode(text || "[D.type]"))

/// An atom's name and type, or a datum's type
/proc/vv_internals_name(datum/D)
	if(isatom(D))
		var/atom/A = D
		return "[A.name] ([A.type])"
	return "[D.type]"

/proc/vv_internals(datum/D)
	var/list/sections = list()
	var/list/summary = list()

	// Components. A component is listed under its own type and its parent types too, so only show each once
	var/list/rows = list()
	var/list/seen = list()
	for(var/key in D.datum_components)
		var/entry = D.datum_components[key]
		for(var/datum/component/C in (islist(entry) ? entry : list(entry)))
			if(seen[C])
				continue
			seen[C] = TRUE
			rows += vv_internals_link(C)
	if(length(rows))
		summary += "[length(rows)] component[length(rows) == 1 ? "" : "s"]"
		sections += "<b>Components</b><br>[rows.Join("<br>")]"

	// The signals it listens to: the signal, what sends it, and the proc that runs
	rows = list()
	for(var/datum/target as anything in D.signal_procs)
		var/list/procs = D.signal_procs[target]
		for(var/sig in procs)
			rows += "<tr><td>[html_encode(sig)]</td><td>[target == D ? "itself" : vv_internals_link(target, vv_internals_name(target))]</td><td>[html_encode("[procs[sig]]")]()</td></tr>"
	if(length(rows))
		summary += "listens to [length(rows)] signal[length(rows) == 1 ? "" : "s"]"
		sections += "<b>Listens to</b><table class='vvi'><tr><th>Signal</th><th>From</th><th>Runs</th></tr>[rows.Join()]</table>"

	// Who listens to its signals
	rows = list()
	var/listeners = 0
	for(var/sig in D.comp_lookup)
		var/list/who = D.comp_lookup[sig]
		var/list/links = list()
		for(var/datum/listener in (islist(who) ? who : list(who)))
			links += listener == D ? "itself" : vv_internals_link(listener, vv_internals_name(listener))
			listeners++
		rows += "<tr><td>[html_encode(sig)]</td><td>[links.Join(", ")]</td></tr>"
	if(length(rows))
		summary += "[listeners] listener[listeners == 1 ? "" : "s"]"
		sections += "<b>Listened to by</b><table class='vvi'><tr><th>Signal</th><th>Listeners</th></tr>[rows.Join()]</table>"

	// Timers: the proc, how long until it runs, how often if it loops, and what it runs on if that isn't this
	rows = list()
	for(var/datum/timedevent/timer as anything in D.active_timers)
		var/datum/callback/callback = timer.callBack
		var/what = callback ? "[callback.delegate]" : "?"
		var/left = round((timer.timeToRun - world.time) / 10, 0.1)
		var/loops = (timer.flags & TIMER_LOOP) ? ", every [timer.wait / 10] s" : ""
		var/on = ""
		if(callback && isdatum(callback.object) && callback.object != D)
			on = " on [vv_internals_link(callback.object, vv_internals_name(callback.object))]"
		rows += "[vv_internals_link(timer, what)] in [left] s[loops][on]"
	if(length(rows))
		summary += "[length(rows)] timer[length(rows) == 1 ? "" : "s"]"
		sections += "<b>Timers</b><br>[rows.Join("<br>")]"

	// Traits, with where they came from
	rows = list()
	for(var/trait in D.status_traits)
		var/list/sources = D.status_traits[trait]
		rows += "[html_encode(trait)] <font size='1'>([html_encode(jointext(sources, ", "))])</font>"
	if(length(rows))
		summary += "[length(rows)] trait[length(rows) == 1 ? "" : "s"]"
		sections += "<b>Traits</b><br>[rows.Join("<br>")]"

	// Status effects
	if(isliving(D))
		var/mob/living/L = D
		rows = list()
		for(var/datum/status_effect/effect as anything in L.status_effects)
			rows += vv_internals_link(effect, "[effect.id || effect.type]")
		if(length(rows))
			summary += "[length(rows)] status effect[length(rows) == 1 ? "" : "s"]"
			sections += "<b>Status effects</b><br>[rows.Join("<br>")]"

	// Which subsystems are processing it
	rows = list()
	for(var/datum/controller/subsystem/subsystem as anything in Master.subsystems)
		if(!("processing" in subsystem.vars))
			continue
		var/list/processing = subsystem.vars["processing"]
		if(islist(processing) && (D in processing))
			rows += vv_internals_link(subsystem, subsystem.name)
	if(length(rows))
		summary += "processed by [rows.Join(", ")]"
	else if(D.isprocessing)
		summary += "set as processing, but in no subsystem's list"

	// Deletion
	var/list/deletion = list()
	if(D.gc_destroyed)
		deletion += "<font color='red'>deleted [round((world.time - D.gc_destroyed) / 10)] s ago, still here</font>"
	if(D.tag)
		deletion += "tag [html_encode(D.tag)]"
	if(length(deletion))
		sections += "<b>Deletion</b><br>[deletion.Join("<br>")]"
		if(!length(summary))
			summary += deletion.Join(", ")

	if(!length(sections) && !length(summary))
		return "<font size='1'>Internals: none</font><hr>"
	return {"<style>.vvi { border-collapse: collapse; } .vvi td, .vvi th { font-size: 7pt; text-align: left; padding: 0 10px 1px 0; vertical-align: top; } .vvi th { color: #666666; font-weight: normal; }</style>
	<details id='vv_internals' ontoggle="document.cookie='vv_internals_open=' + (this.open ? 1 : 0) + ';path=/'">
		<summary><font size='1'><b>Internals:</b> [summary.Join(", ") || "see below"]</font></summary>
		<font size='1'>[sections.Join("<br><br>")]</font>
	</details>
	<script type='text/javascript'>if (document.cookie.indexOf('vv_internals_open=1') != -1) document.getElementById('vv_internals').open = true;</script>
	<hr>"}
