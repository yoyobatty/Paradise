/* HUD DATUMS */
GLOBAL_LIST_EMPTY(all_huds)

///GLOBAL HUD LIST
GLOBAL_LIST_INIT(huds, alist(
	DATA_HUD_SECURITY_BASIC = new/datum/atom_hud/data/human/security/basic(),
	DATA_HUD_SECURITY_ADVANCED = new/datum/atom_hud/data/human/security/advanced(),
	DATA_HUD_MEDICAL_BASIC = new/datum/atom_hud/data/human/medical/basic(),
	DATA_HUD_MEDICAL_ADVANCED = new/datum/atom_hud/data/human/medical/advanced(),
	DATA_HUD_DIAGNOSTIC_BASIC = new/datum/atom_hud/data/diagnostic/basic(),
	DATA_HUD_DIAGNOSTIC_ADVANCED = new/datum/atom_hud/data/diagnostic/advanced(),
	DATA_HUD_HYDROPONIC = new/datum/atom_hud/data/hydroponic(),
	DATA_HUD_JANITOR = new/datum/atom_hud/data/janitor(),
	DATA_HUD_PRESSURE = new/datum/atom_hud/data/pressure(),
	DATA_HUD_MALF_AI = new/datum/atom_hud/data/human/malf_ai(),
	DATA_HUD_ANOMALOUS = new/datum/atom_hud/data/anomalous(),
	ANTAG_HUD_CULT = new/datum/atom_hud/antag(),
	ANTAG_HUD_REV = new/datum/atom_hud/antag(),
	ANTAG_HUD_OPS = new/datum/atom_hud/antag(),
	ANTAG_HUD_WIZ  = new/datum/atom_hud/antag(),
	ANTAG_HUD_SHADOW  = new/datum/atom_hud/antag(),
	ANTAG_HUD_TRAITOR = new/datum/atom_hud/antag/hidden(),
	ANTAG_HUD_NINJA = new/datum/atom_hud/antag/hidden(),
	ANTAG_HUD_CHANGELING = new/datum/atom_hud/antag/hidden(),
	ANTAG_HUD_VAMPIRE = new/datum/atom_hud/antag/hidden(),
	ANTAG_HUD_ABDUCTOR = new/datum/atom_hud/antag/hidden(),
	DATA_HUD_ABDUCTOR = new/datum/atom_hud/abductor(),
	ANTAG_HUD_EVENTMISC = new/datum/atom_hud/antag/hidden(),
	ANTAG_HUD_BLOB = new/datum/atom_hud/antag/hidden(),
	ANTAG_HUD_ZOMBIE = new/datum/atom_hud/antag(),
	ANTAG_HUD_MIND_FLAYER = new/datum/atom_hud/antag/hidden(),
	DATA_HUD_HERETIC = new/datum/atom_hud/data/heretic(),
	ANTAG_HUD_HERETIC = new/datum/atom_hud/antag/hidden(),
	ANTAG_HUD_HERETIC_BEAST = new/datum/atom_hud/antag/hidden(),
	ANTAG_HUD_UPLIFTED_TEAMLESS = new/datum/atom_hud/antag/hidden/secondary(),
	))

/datum/atom_hud
	/// All the atoms that display this hud.
	var/list/atom/hudatoms = list()
	/// All the mobs who can see this hud, and their sources. each_mob = list(source/1, source/2).
	var/list/mob/hudusers = list()
	/// Indexes for the atom's hud_list.
	var/list/hud_icons = list()
	/// Do we ignore the invisibility check? Used by anom huds so we can see our stuff.
	var/ignore_invisibility_check = FALSE


/datum/atom_hud/New()
	GLOB.all_huds += src

/datum/atom_hud/Destroy()
	for(var/v in hudusers)
		remove_hud_from(v)
	for(var/v in hudatoms)
		remove_from_hud(v)
	GLOB.all_huds -= src
	return ..()

/// Removes `source` from mob's hud sources, and if mob has no hud sources, removes their ability to see this hud
/datum/atom_hud/proc/remove_hud_from(mob/M, atom/source)
	if(!M)
		return
	if(src in M.permanent_huds)
		return
	if(hudusers[M])
		hudusers[M] -= source
	if(hudusers[M] && length(hudusers[M]))
		return

	for(var/atom/A in hudatoms)
		remove_hud_images(M, A)
	hudusers -= M
	M.reload_huds()

/// Removes a single item from being displayed on this hud, for example, removes one mess from janihud.
/datum/atom_hud/proc/remove_from_hud(atom/A)
	if(!A)
		return
	for(var/mob/M in hudusers)
		remove_hud_images(M, A)
	hudatoms -= A
	UnregisterSignal(A, COMSIG_MOVABLE_Z_CHANGED)

/// Removes all of the hud pictures that `A` produces from mob `M`'s view.
/datum/atom_hud/proc/remove_hud_images(mob/M, atom/A) // Unsafe, no sanity apart from client.
	if(!M || !M.client || !A)
		return
	for(var/i in hud_icons)
		// Taking nothing away still looks through the whole list
		if(A.hud_list[i])
			M.client.images -= A.hud_list[i]

/// Adds `source` to mob's sources of this hud, and shows them all the pictures on the hud
/datum/atom_hud/proc/add_hud_to(mob/M, atom/source)
	if(!M)
		return
	if(!(M in hudusers))
		hudusers[M] = list()
	hudusers[M] |= source
	// They only get what's on the z-level they're looking at, checked here to save a call for everything that isn't
	var/z = M.hud_z
	if(!M.client || !z)
		return
	for(var/atom/A in hudatoms)
		var/turf/T = get_turf(A)
		if(T?.z == z)
			add_hud_images(M, A)

/// Adds single atom `A` to the list of pictures this hud will display. Shows them to mobs with this hud.
/datum/atom_hud/proc/add_to_hud(atom/A)
	if(!A)
		return
	hudatoms |= A
	// Its pictures only go to those looking at the z-level it's on, so we need to hear when that changes
	if(ismovable(A))
		RegisterSignal(A, COMSIG_MOVABLE_Z_CHANGED, PROC_REF(on_atom_changed_z), TRUE)
	for(var/mob/M in hudusers)
		add_hud_images(M, A)

/// Adds all hud images that `A` produces to player `M`'s view.
/datum/atom_hud/proc/add_hud_images(mob/M, atom/A) // Unsafe, no sanity apart from client.
	if(!M || !M.client || !A)
		return
	// Nothing on another z-level can be on their screen, and every image they hold is looked at every tick
	var/turf/T = get_turf(A)
	if(!T || T.z != M.hud_z)
		return
	if((A.invisibility > M.see_invisible) && !ignore_invisibility_check) // yee yee ass snowflake check for our yee yee ass snowflake huds
		return
	for(var/i in hud_icons)
		if(A.hud_list[i])
			M.client.images |= A.hud_list[i]

/// An atom on this hud changed z-level. Those looking at the one it left lose its pictures, those looking at the one it's on now get them.
/datum/atom_hud/proc/on_atom_changed_z(atom/movable/source, turf/old_turf, turf/new_turf)
	SIGNAL_HANDLER // COMSIG_MOVABLE_Z_CHANGED
	var/old_z = old_turf?.z
	for(var/mob/M in hudusers)
		if(!M.client || !M.hud_z)
			continue
		if(M.hud_z == old_z)
			remove_hud_images(M, source)
		else
			add_hud_images(M, source)

/// Mob `M` is looking at another z-level now. Takes away the pictures of what's on the one they were looking at and shows them what's on this one.
/datum/atom_hud/proc/user_changed_z(mob/M, old_z)
	var/new_z = M.hud_z
	var/list/atom/now_in_view = list()
	for(var/atom/A as anything in hudatoms)
		var/turf/T = get_turf(A)
		if(!T)
			continue
		if(T.z == old_z)
			remove_hud_images(M, A)
		else if(T.z == new_z)
			now_in_view += A
	for(var/atom/A as anything in now_in_view)
		add_hud_images(M, A)

//MOB PROCS
/// The z-level our client is looking at, which is the one its eye is on. 0 if that's nowhere.
/mob/proc/get_hud_z()
	var/turf/eye_turf = get_turf(client.eye)
	return eye_turf ? eye_turf.z : 0

/// Call this whenever where our client looks from could have changed z-level. Swaps its hud pictures over if it has.
/mob/proc/update_hud_z()
	if(!client || isnull(hud_z))
		return
	watch_hud_eye()
	var/new_z = get_hud_z()
	if(new_z == hud_z)
		return
	var/old_z = hud_z
	hud_z = new_z
	for(var/datum/atom_hud/hud as anything in GLOB.all_huds)
		if(src in hud.hudusers)
			hud.user_changed_z(src, old_z)

/// When our client looks through something else that can move, that thing changing z-level matters as much as us doing it.
/mob/proc/watch_hud_eye()
	var/atom/movable/eye = client.eye
	var/eye_uid = (ismovable(eye) && eye != src) ? eye.UID() : null
	if(eye_uid == hud_eye_uid)
		return
	var/atom/movable/old_eye = locateUID(hud_eye_uid)
	if(old_eye)
		UnregisterSignal(old_eye, COMSIG_MOVABLE_Z_CHANGED)
	hud_eye_uid = eye_uid
	if(eye_uid)
		RegisterSignal(eye, COMSIG_MOVABLE_Z_CHANGED, PROC_REF(on_hud_eye_changed_z))

/mob/proc/on_hud_eye_changed_z(atom/movable/source)
	SIGNAL_HANDLER // COMSIG_MOVABLE_Z_CHANGED
	update_hud_z()

/mob/on_changed_z_level(turf/old_turf, turf/new_turf, notify_contents = TRUE)
	. = ..()
	update_hud_z()

/mob/proc/reload_huds()
	// First time since logging in, so work out which z-level to load them for
	if(client && isnull(hud_z))
		hud_z = get_hud_z()
		watch_hud_eye()

	//var/gang_huds = list()
	//if(ticker.mode)
	//	for(var/datum/gang/G in ticker.mode.gangs)
	//		gang_huds += G.ganghud

	var/serv_huds = list()//mindslaves and/or vampire thralls
	if(SSticker.mode)
		for(var/datum/mindslaves/serv in (SSticker.mode.vampires | SSticker.mode.traitors))
			serv_huds += serv.thrallhud

	for(var/datum/atom_hud/hud in (GLOB.all_huds|serv_huds))//|gang_huds))
		if(src in hud.hudusers)
			var/list/hudusers = hud.hudusers[src]
			hud.add_hud_to(src, hudusers[1])

/mob/new_player/reload_huds()
	return

/mob/proc/add_click_catcher()
	client.screen += client.void

/mob/new_player/add_click_catcher()
	return
