// View Variables marks what's been changed. A var with a plain value (a number, text, a path, a file or null) that isn't its
// default says "changed", with a link that puts the default back. A var an admin edited says "edited", with an undo that
// puts back what it was before the edit. Checkboxes by the search box show only those vars.
// References and lists aren't compared, since the game sets those as it runs and nearly all of them would be marked.

/// Admin edits made through View Variables, as var name = list of list(the value before, who, world.time), oldest first
/datum/var/list/vv_edits

#define VV_EDITS_KEPT 10

/// Vars that hold the game's running state rather than a setting, so they're never compared with their default
GLOBAL_LIST_INIT(vv_uncompared_vars, list(
	"loc" = TRUE, "x" = TRUE, "y" = TRUE, "z" = TRUE, "contents" = TRUE, "locs" = TRUE, "vars" = TRUE, "verbs" = TRUE,
	"type" = TRUE, "parent_type" = TRUE, "tag" = TRUE, "overlays" = TRUE, "underlays" = TRUE, "vis_contents" = TRUE,
	"vis_locs" = TRUE, "appearance" = TRUE, "transform" = TRUE, "filters" = TRUE, "pixloc" = TRUE,
	"override" = TRUE, "animate_movement" = TRUE, "pixel_step_size" = TRUE, "render_target" = TRUE,
	"bound_x" = TRUE, "bound_y" = TRUE, "step_x" = TRUE, "step_y" = TRUE,
	"vv_edits" = TRUE, "var_edited" = TRUE, "gc_destroyed" = TRUE, "unique_datum_id" = TRUE, "md5_unique_datum_id" = TRUE,
	"cached_ref" = TRUE, "isprocessing" = TRUE,
	// Set on every atom or item as it's made
	"initialized" = TRUE, "flags_2" = TRUE, "lighting_corners_initialised" = TRUE, "power_initialized" = TRUE,
	"runechat_msg_location" = TRUE, "hitsound" = TRUE, "move_resist" = TRUE, "move_force" = TRUE, "pull_force" = TRUE,
))

/// Whether a var holds a plain value that isn't its default
/proc/vv_var_changed(datum/D, var_name)
	if(GLOB.vv_uncompared_vars[var_name] || !(var_name in D.vars))
		return FALSE
	var/value = D.vars[var_name]
	var/default = initial(D.vars[var_name])
	if(islist(value) || islist(default) || isdatum(value) || isdatum(default))
		return FALSE
	// Objects set this to max_integrity as they're made, so only damage counts
	if(var_name == "obj_integrity" && value == D.vars["max_integrity"])
		return FALSE
	if(isnum(value) && isnum(default))
		return abs(value - default) > 0.00001
	return value != default

/// The attributes for a var's row and the marks that go after its edit links
/proc/vv_var_marks(datum/D, var_name)
	var/edited = length(LAZYACCESS(D.vv_edits, var_name))
	var/changed = vv_var_changed(D, var_name)
	if(!edited && !changed)
		return list("", "")
	var/list/marks = list()
	if(edited)
		var/list/last = D.vv_edits[var_name][edited]
		marks += "<font size='1' color='red' title='[html_encode("was [vv_short_value(last[4] ? locateUID(last[1]) : last[1])], by [last[2]]")]'>edited (<a href='byond://?_src_=vars;vvundo=[D.UID()];varname=[var_name]'>undo</a>)</font>"
	if(changed)
		marks += "<font size='1' color='#8a6d00' title='[html_encode("default: [vv_short_value(initial(D.vars[var_name]))]")]'>changed (<a href='byond://?_src_=vars;vvdefault=[D.UID()];varname=[var_name]'>default</a>)</font>"
	return list("[edited ? " data-edited='1'" : ""][changed ? " data-changed='1'" : ""]", "[marks.Join(" ")] ")

/// A value cut short to fit in a tooltip
/proc/vv_short_value(value)
	if(isnull(value))
		return "null"
	var/text = istext(value) ? "\"[value]\"" : "[value]"
	return length(text) > 60 ? "[copytext(text, 1, 58)]..." : text

/// Remembers what a var was before an admin edited it, for undo
/proc/vv_note_edit(datum/D, var_name, old_value, client/by)
	if(!istype(D))
		return
	LAZYINITLIST(D.vv_edits)
	LAZYINITLIST(D.vv_edits[var_name])
	var/list/history = D.vv_edits[var_name]
	// A datum is kept as its UID, so an undo never keeps it from being deleted
	var/kept = old_value
	var/is_uid = FALSE
	if(isdatum(old_value))
		var/datum/old_datum = old_value
		kept = old_datum.UID()
		is_uid = TRUE
	history += list(list(kept, by ? by.key : "?", world.time, is_uid))
	if(length(history) > VV_EDITS_KEPT)
		history.Cut(1, 2)

/// Puts a var back to what it was before its last edit
/client/proc/vv_undo_var(datum/D, var_name)
	var/list/history = LAZYACCESS(D?.vv_edits, var_name)
	if(!length(history))
		to_chat(src, SPAN_NOTICE("There's no edit of [var_name] to undo."))
		return FALSE
	var/list/last = history[length(history)]
	var/value = last[1]
	if(last[4])
		value = locateUID(value)
		if(!value)
			to_chat(src, SPAN_WARNING("What [var_name] held before has been deleted since."))
			return FALSE
	var/was = D.vars[var_name]
	if(!D.vv_edit_var(var_name, value))
		to_chat(src, SPAN_WARNING("The object refused the undo."))
		return FALSE
	history.Cut(length(history))
	if(!length(history))
		D.vv_edits -= var_name
	vv_log_change(D, var_name, was, value, "undid the last edit of")
	return TRUE

/// Puts a var back to its default. It can be undone like any other edit
/client/proc/vv_restore_default(datum/D, var_name)
	if(!istype(D) || !(var_name in D.vars) || !vv_varname_lockcheck(var_name))
		return FALSE
	var/was = D.vars[var_name]
	var/default = initial(D.vars[var_name])
	if(!D.vv_edit_var(var_name, default))
		to_chat(src, SPAN_WARNING("The object refused the edit."))
		return FALSE
	vv_note_edit(D, var_name, was, src)
	vv_log_change(D, var_name, was, default, "restored the default of")
	return TRUE

/// Logs an undo, a restored default or an edit from the page the same way as E and C do
/client/proc/vv_log_change(datum/D, var_name, old_value, new_value, what)
	log_world("### VarEdit by [src]: [D.type] [var_name]=[html_encode("[new_value]")] ([what], was [html_encode("[old_value]")])")
	log_admin("[key_name(src)] [what] [D]'s [var_name]: [old_value] to [new_value]")
	message_admins("[key_name_admin(src)] [what] [D]'s [var_name]: [html_encode("[old_value]")] to [html_encode("[new_value]")]")

/// How many vars are edited and changed, for the top of the page
/proc/vv_change_counts(datum/D)
	var/edited = 0
	var/changed = 0
	for(var/var_name in D.vars)
		if(length(LAZYACCESS(D.vv_edits, var_name)))
			edited++
		if(vv_var_changed(D, var_name))
			changed++
	return "<br><font size='1'>[edited] edited, [changed] changed from default</font>"

#undef VV_EDITS_KEPT
