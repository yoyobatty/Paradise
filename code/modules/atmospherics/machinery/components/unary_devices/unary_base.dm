/obj/machinery/atmospherics/unary
	initialize_directions = SOUTH
	layer = TURF_LAYER+0.1
	device_type = UNARY
	/// The current air contents of this device, the same gas as airs[1]
	var/datum/gas_mixture/air_contents
	/// The tile MILLA is watching for us, see watched_tile_offset()
	var/turf/watched_turf
	/// Where that tile's values start in SSair.watched_tiles, minus one
	var/watched_offset

/obj/machinery/atmospherics/unary/New()
	parents = new /list(device_type)
	..()

/obj/machinery/atmospherics/unary/Initialize(mapload)
	. = ..()
	initialize_directions = dir
	create_device_airs()
	air_contents = airs[1]

/obj/machinery/atmospherics/unary/Destroy()
	if(!isnull(watched_offset))
		SSair.unwatch_tile(watched_offset)
		watched_offset = null
	watched_turf = null
	return ..()

/// Where our tile's values start in SSair.watched_tiles, minus one. Null when they can't stand in for reading the tile's air.
/obj/machinery/atmospherics/unary/proc/watched_tile_offset(turf/T)
	if(watched_turf != T)
		// First time here, or we got moved (shuttles)
		if(!isnull(watched_offset))
			SSair.unwatch_tile(watched_offset)
		watched_turf = T
		watched_offset = SSair.watch_tile(T)
		return null
	// Something already read or changed this tile's air this tick, so a normal read would give its copy and not MILLA's.
	if(T.bound_air && T.bound_air.lastread >= SSair.milla_tick)
		return null
	if(isnull(SSair.watched_tiles))
		return null
	return watched_offset

/obj/machinery/atmospherics/unary/get_node_connects()
	return list(dir)

/obj/machinery/atmospherics/unary/default_change_direction_wrench(mob/user, obj/item/wrench/W)
	if(..())
		initialize_directions = dir
		if(nodes[1])
			nodes[1].disconnect(src)
		nodes[1] = null
		nullifyPipenet(parents[1])
		atmos_init()
		if(nodes[1])
			nodes[1].atmos_init()
			nodes[1].addMember(src)
		build_network()
		. = 1

/obj/machinery/atmospherics/unary/update_pipe_image()
	. = ..()
	if(parents[1])
		for(var/mob/crawler in parents[1].crawlers)
			var/mob/living/current_crawler = crawler
			current_crawler.update_pipe_vision(src)

// We only have one end, so we don't check which one is asked about
/obj/machinery/atmospherics/unary/setPipenet(datum/pipeline/P)
	parents[1] = P

/obj/machinery/atmospherics/unary/returnPipenet()
	return parents[1]
