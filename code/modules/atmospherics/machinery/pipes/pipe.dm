/obj/machinery/atmospherics/pipe
	var/datum/gas_mixture/ghost_pipeline // used when reconstructing a pipeline that broke
	var/datum/pipeline/parent
	var/volume = 0
	force = 20
	can_unwrench = TRUE
	damage_deflection = 12
	can_be_undertile = TRUE

	//Buckling
	can_buckle = TRUE
	buckle_requires_restraints = TRUE

	flags_2 = NO_MALF_EFFECT_2

/obj/machinery/atmospherics/pipe/Initialize(mapload)
	. = ..()
	//so pipes under walls are hidden
	if(iswallturf(get_turf(src)))
		level = 1

/obj/machinery/atmospherics/pipe/Destroy()
	var/turf/T = get_turf(src)
	if(ghost_pipeline)
		var/datum/gas_mixture/ghost_copy = new()
		ghost_copy.copy_from(ghost_pipeline)
		T.blind_release_air(ghost_copy.remove(volume / ghost_pipeline.volume))

	for(var/obj/machinery/atmospherics/meter/meter in T)
		if(meter.target == src)
			var/obj/item/pipe_meter/PM = new (T)
			meter.transfer_fingerprints_to(PM)
			qdel(meter)

	// if we're somehow by ourself
	if(parent && !QDELETED(parent) && length(parent.members) == 1 && parent.members[1] == src)
		qdel(parent)
	parent = null

	. = ..()

	for(var/i in 1 to device_type)
		var/obj/machinery/atmospherics/node = nodes[i]
		if(!node)
			continue
		node.disconnect(src)
		node.defer_build_network()
		nodes[i] = null

/obj/machinery/atmospherics/pipe/returnPipenet(obj/machinery/atmospherics/A)
	return parent

/obj/machinery/atmospherics/pipe/wrench_floor_check()
	var/turf/T = get_turf(src)
	return level == 1 && T.transparent_floor

/obj/machinery/atmospherics/pipe/examine(mob/user)
	. = ..()
	. += SPAN_NOTICE("This pipe can be disconnected from a pipenet using a wrench. If the pipe's pressure is too high, you'll end up flying.")

/obj/machinery/atmospherics/pipe/pipeline_expansion()
	return nodes.Copy()

/obj/machinery/atmospherics/pipe/return_obj_air()
	RETURN_TYPE(/datum/gas_mixture)
	if(!parent)
		return 0
	return parent.air

/obj/machinery/atmospherics/pipe/return_analyzable_air()
	if(!parent)
		return null
	return list(parent.air) + parent.other_airs

/obj/machinery/atmospherics/pipe/build_network(remove_deferral = FALSE)
	if(!parent)
		parent = new /datum/pipeline()
		parent.build_pipeline(src)
	..()

/obj/machinery/atmospherics/pipe/setPipenet(datum/pipeline/P)
	parent = P

/obj/machinery/atmospherics/pipe/disconnect(obj/machinery/atmospherics/reference)
	for(var/i in 1 to device_type)
		if(nodes[i] != reference)
			continue
		// A pipe on that end shares our pipenet, so it has to be rebuilt
		if(istype(nodes[i], /obj/machinery/atmospherics/pipe))
			qdel(parent)
		nodes[i] = null
	check_nodes_exist()
	update_icon()

/obj/machinery/atmospherics/pipe/change_color(new_color)
	..()
	//for updating connected atmos device pipes (i.e. vents, manifolds, etc)
	for(var/obj/machinery/atmospherics/node in nodes)
		node.update_underlays()

/obj/machinery/atmospherics/pipe/color_cache_name(obj/machinery/atmospherics/node)
	if(istype(node, /obj/machinery/atmospherics/pipe/manifold) || istype(node, /obj/machinery/atmospherics/pipe/manifold4w))
		if(pipe_color == node.pipe_color)
			return node.pipe_color
		else
			return null
	else if(istype(node, /obj/machinery/atmospherics/pipe/simple))
		return node.pipe_color
	else
		return pipe_color

// A check to make sure our nodes exist - self-delete if none are present
/obj/machinery/atmospherics/pipe/proc/check_nodes_exist()
	for(var/node in nodes)
		if(node)
			return 1 // 1: some nodes exist, we continue existing
	deconstruct()
	return 0 // 0: No nodes exist
