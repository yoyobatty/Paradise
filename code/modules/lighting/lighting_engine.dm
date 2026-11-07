// The lighting engine (rust/src/lighting) keeps the lighting corners: what each light gives each corner, and what each
// lighting object should draw. It also works out what each light can see, the way view() would. DM decides when a light
// needs working out, works out the falloff (falloff_table()) and draws the lighting objects.
//
// The engine knows turfs by their place in the world, and keeps a few things about each one, which it's told whenever
// they change: whether it blocks light from every direction (IS_OPAQUE_TURF) or only some, whether it has a lighting
// object, and whether lights near it have to look with view() (lighting_view_only).

#if LIGHTING_SOFT_THRESHOLD != 0
#error The lighting engine draws corners for a LIGHTING_SOFT_THRESHOLD of 0
#endif

/// How many lighting objects to draw per call to the engine
#define LIGHTING_ENGINE_BATCH 400

/datum/controller/subsystem/lighting
	/// Turfs tell the engine when they change: it has every turf's flags
	var/engine_turfs_ready = FALSE
	/// Light source ids as the engine knows them -> the light source
	var/list/datum/light_source/engine_lights = list()
	var/list/engine_free_ids = list()
	/// Light range (as text, to the last bit) -> the number of the engine's falloff table for it
	var/list/falloff_tables = list()
	/// The world's size when the engine was set up: it numbers turfs by it
	var/engine_maxx = 0
	var/engine_maxy = 0
	/// The z-levels there were when the engine was given every turf's flags. Lights on newer ones look with view().
	var/engine_maxz = 0

/datum/light_source
	/// What the lighting engine knows us by, or 0
	var/engine_id = 0

/// Starts the engine afresh for the world as it is
/datum/controller/subsystem/lighting/proc/engine_setup()
	// A few turfs and where they are, so the engine can check it numbers turfs the way BYOND does
	var/list/turfs = list()
	var/list/coordinates = list()
	for(var/list/spot in list(list(1, 1, 1), list(world.maxx, 1, 1), list(1, world.maxy, 1), list(world.maxx, world.maxy, world.maxz), list(round(world.maxx / 2), round(world.maxy / 3), max(1, world.maxz - 1))))
		var/turf/T = locate(spot[1], spot[2], spot[3])
		if(T)
			turfs += T
			coordinates += spot
	var/version = rustlibs_lighting_setup(world.maxx, world.maxy, LIGHTING_ROUND_VALUE, turfs, coordinates)
	if(version != LIGHTING_ENGINE_VERSION)
		CRASH("The lighting engine in rustlibs is version [version], this code wants [LIGHTING_ENGINE_VERSION]")
	engine_maxx = world.maxx
	engine_maxy = world.maxy
	engine_turfs_ready = FALSE
	engine_lights.Cut()
	engine_free_ids.Cut()
	falloff_tables.Cut()

/// Hands every turf's flags over: from here on turfs tell the engine when theirs change
/datum/controller/subsystem/lighting/proc/engine_hand_over_turfs()
	var/list/flags = list()
	for(var/turf/T in world)
		if(T.lighting_object || T.directional_opacity || T.lighting_view_only)
			flags.Add(T, T.lighting_engine_flags())
	rustlibs_lighting_flags(flags)
	engine_turfs_ready = TRUE
	engine_maxz = world.maxz

/// The engine starts again and every light relights: the map loader made the world bigger, which numbers turfs anew,
/// or the subsystem was made afresh
/datum/controller/subsystem/lighting/proc/engine_world_resized()
	log_world("Lighting: starting the lighting engine again for a [world.maxx] by [world.maxy] world, relighting everything")
	engine_setup()
	engine_hand_over_turfs()
	for(var/datum/light_source/L)
		L.engine_id = 0
		if(QDELETED(L))
			continue
		L.applied = FALSE
		L.force_update()

/datum/controller/subsystem/lighting/proc/engine_id_for(datum/light_source/L)
	var/id
	if(length(engine_free_ids))
		id = engine_free_ids[length(engine_free_ids)]
		engine_free_ids.len--
	else
		id = length(engine_lights) + 1
		engine_lights.len = id
	engine_lights[id] = L
	L.engine_id = id
	return id

/// The light source is gone: the engine takes its light off and forgets it
/datum/controller/subsystem/lighting/proc/engine_forget(datum/light_source/L)
	var/id = L.engine_id
	if(!id)
		return
	L.engine_id = 0
	rustlibs_lighting_forget(id)
	engine_lights[id] = null
	engine_free_ids += id

/**
 * The number of the engine's falloff table for a light range, made the first time a light of that range comes up.
 *
 * A table holds how much of a light's brightness reaches each corner around it, for every corner a light of this
 * range can reach: entry (ix, iy) is the corner (ix - reach - 0.5, iy - reach - 0.5) tiles from the light's turf.
 */
/datum/controller/subsystem/lighting/proc/falloff_table(range)
	var/key = num2text(range, 12)
	. = falloff_tables[key]
	if(.)
		return
	var/reach = CEILING(range, 1)
	var/dim = 2 * reach + 2
	var/range_divisor = max(1, range)
	var/list/values = new /list(dim * dim)
	var/i = 0
	for(var/ix in 0 to dim - 1)
		var/dx = ix - reach - 1 + 0.5
		for(var/iy in 0 to dim - 1)
			var/dy = iy - reach - 1 + 0.5
			values[++i] = 1 - CLAMP01(sqrt((dx) ** 2 + (dy) ** 2 + LIGHTING_HEIGHT) / range_divisor)
	. = length(falloff_tables) + 1
	rustlibs_lighting_sheet(., dim, values)
	falloff_tables[key] = .

/// A light source has looked around: the engine works out what it gives every corner it sees
/// Works out what the light gives every corner it can see. Without `seen`, the engine works out what it can see too, and
/// this returns FALSE if it couldn't, for the light to look with view() instead.
/datum/controller/subsystem/lighting/proc/engine_update(datum/light_source/L, light_reach, list/seen, vis_only)
	var/turf/pixel_turf = L.pixel_turf
	var/turf/source_turf = L.source_turf
	if(!seen && source_turf.z > engine_maxz)
		return FALSE
	var/result = rustlibs_lighting_update(L.engine_id || engine_id_for(L), pixel_turf.x, pixel_turf.y, source_turf.z, L.light_power, L.lum_r, L.lum_g, L.lum_b, falloff_table(L.light_range), vis_only ? 1 : 0, source_turf.x, source_turf.y, light_reach, seen)
	return result != 2

/// The lights on the turf's corners look around again
/datum/controller/subsystem/lighting/proc/engine_reconsider(turf/T)
	if(!engine_turfs_ready) // no light has lit anything yet
		return
	var/list/ids = list()
	if(rustlibs_lighting_affecting(T, ids) <= 0)
		return
	for(var/id in ids)
		var/datum/light_source/L = engine_lights[id]
		L?.vis_update()

/// The engine's corner stage, then drawing: the lighting objects whose corners it changed, and those queued here (made
/// since, or asked to update). TRUE if it got through everything.
/datum/controller/subsystem/lighting/proc/engine_draw(init_tick_checks)
	var/list/out = list()
	var/left = 1
	while(left > 0)
		out.Cut()
		left = rustlibs_lighting_flush(LIGHTING_ENGINE_BATCH, out)
		for(var/at = 1, at <= length(out), at += 14)
			var/turf/T = out[at]
			var/datum/lighting_object/O = T.lighting_object
			if(O && !O.needs_update) // those queued here are drawn below
				O.draw(out[at + 1], out[at + 2], out[at + 3], out[at + 4], out[at + 5], out[at + 6], out[at + 7], out[at + 8], out[at + 9], out[at + 10], out[at + 11], out[at + 12], out[at + 13])
		if(init_tick_checks)
			CHECK_TICK
		else if(left > 0 && MC_TICK_CHECK)
			return FALSE
	var/list/queue = objects_queue
	var/i = 0
	while(i < length(queue))
		i++
		var/datum/lighting_object/O = queue[i]
		if(QDELETED(O))
			continue
		O.update()
		O.needs_update = FALSE
		if(init_tick_checks)
			CHECK_TICK
		else if(MC_TICK_CHECK)
			break
	if(i)
		queue.Cut(1, i + 1)
	return !length(queue)

/// What the lighting engine keeps about a turf
/turf/proc/lighting_engine_flags()
	. = 0
	if(IS_OPAQUE_TURF(src))
		. |= LIGHTING_ENGINE_OPAQUE
	else if(directional_opacity)
		. |= LIGHTING_ENGINE_PARTLY_OPAQUE
	if(lighting_view_only)
		. |= LIGHTING_ENGINE_VIEW_ONLY
	if(lighting_object)
		. |= LIGHTING_ENGINE_OBJECT

/turf
	/// Something on this turf blocks sight without directional_opacity counting it (a multi-tile door), so lights near it look with view()
	var/lighting_view_only = FALSE

/turf/proc/set_lighting_view_only()
	if(lighting_view_only)
		return
	lighting_view_only = TRUE
	lighting_engine_push()

/// The door and its fillers block sight on turfs that don't count them, so lights near them have to look with view()
/obj/machinery/door/proc/set_lighting_view_only()
	for(var/turf/T in locs)
		T.set_lighting_view_only()
	for(var/obj/airlock_filler_object/filler as anything in fillers)
		var/turf/T = filler.loc
		if(isturf(T))
			T.set_lighting_view_only()

/// Tells the lighting engine this turf's flags may have changed
/turf/proc/lighting_engine_push()
	if(SSlighting.engine_turfs_ready)
		rustlibs_lighting_flag(src, lighting_engine_flags())

#undef LIGHTING_ENGINE_BATCH
