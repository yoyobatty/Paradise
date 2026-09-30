GLOBAL_LIST_INIT(turf_rad_item_cache, list("[ALPHA_RAD]" = list(), "[BETA_RAD]" = list(), "[GAMMA_RAD]" = list()))
#define WRAP_INDEX(index, length)((index - 1) % length + 1)

/datum/radiation_wave
	/// The thing that spawned this radiation wave
	var/source
	/// The top left corner of the wave, from which we begin iteration on a step
	var/turf/master_turf
	/// How far we've moved
	var/steps = 0
	/// The strength at the origin. Multiplied by the weight of a tile to determine the strength of radiation there.
	var/intensity
	/// The direction of movement
	var/move_dir
	/// The directions to the side of the wave, stored for easy looping
	var/list/__dirs
	/// Weights of the current tiles in the step going clockwise from the top left corner. Starts as one tile with a weight of 1
	var/list/weights = list(1)
	/// Indexes in weights that are above zero, in order
	var/list/nonzero_indexes
	/// Sum of all weights
	var/weight_sum = 1
	/// The type of particle emitted
	var/emission_type = ALPHA_RAD

/datum/radiation_wave/New(atom/_source, _intensity = 0, _emission_type = ALPHA_RAD)

	source = _source
	master_turf = get_turf(_source)
	intensity = _intensity
	emission_type = _emission_type
	START_PROCESSING(SSradiation, src)

/datum/radiation_wave/Destroy()
	. = QDEL_HINT_IWILLGC
	STOP_PROCESSING(SSradiation, src)
	..()


/// Deals with wave propagation. Radiation waves always expand in a 90 degree cone
/datum/radiation_wave/process()
	// If the wave is too weak to do anything
	if(weight_sum * intensity < RAD_BACKGROUND_RADIATION)
		qdel(src)
		return
	/// We start iteration from the top left corner of the current wave step
	master_turf = get_step(master_turf, NORTHWEST)
	if(!master_turf)
		qdel(src)
		return
	steps++
	var/edge_length = 2 * steps
	var/ring_length = 8 * steps
	// Zero weight tiles are left as null
	var/list/new_weights = new /list(ring_length)
	var/list/new_nonzero_indexes = list()
	var/list/turf_atoms_cache = GLOB.turf_rad_item_cache["[emission_type]"]
	weight_sum = 0
	var/ratio = steps > 1 ? (steps - 1) / steps : (1 / 8)
	var/weight_length = length(weights)
	var/master_x = master_turf.x
	var/master_y = master_turf.y
	var/master_z = master_turf.z
	// Going around the square stops at the edge of the map, so everything after that point is skipped
	var/first_off_map = ring_length + 1
	if(master_x + edge_length > world.maxx)
		first_off_map = world.maxx - master_x + 2
	else if(master_y - edge_length < 1)
		first_off_map = edge_length + master_y + 1
	// Iterate around the periphery of a square for each step, only on tiles the last step can reach
	for(var/i in get_indexes_to_check(edge_length, ring_length))
		if(i >= first_off_map)
			break
		var/edge = floor((i - 1) / edge_length)
		// our index along the edge we are on, each corner starts a new edge.
		var/index = i - edge * edge_length
		var/offset = edge * (edge_length - 2)
		// Get weights for rear, right rear and left rear tiles if they were part of the previous step, where rear means towards the center and left and right are along the edge we are on
		var/weight_left = index > 2 ? weights[WRAP_INDEX((index + offset - 2), weight_length)] : 0
		var/weight_center = index > 1 ? weights[WRAP_INDEX((index + offset - 1), weight_length)] : 0
		var/weight_right = index < edge_length ? weights[WRAP_INDEX((index + offset), weight_length)] : 0
		if(!(weight_left + weight_center + weight_right))
			continue
		// Clockwise from the top left corner: top, right, bottom, left
		var/turf/current_turf
		switch(edge)
			if(0)
				current_turf = locate(master_x + index - 1, master_y, master_z)
			if(1)
				current_turf = locate(master_x + edge_length, master_y - index + 1, master_z)
			if(2)
				current_turf = locate(master_x + edge_length - index + 1, master_y - edge_length, master_z)
			if(3)
				current_turf = locate(master_x, master_y - edge_length + index - 1, master_z)
		// The weight of the current tile the average of the weights of the tiles we checked for earlier
		// And is reduced by irradiating things and getting blocked
		var/new_weight = radiate(source, current_turf, (ratio) * (weight_left + weight_center + weight_right) / ((1 + (index > 1 && steps > 1) + (index > 2 && index < edge_length))), emission_type, turf_atoms_cache)
		if(new_weight)
			new_weights[i] = new_weight
			new_nonzero_indexes += i
			weight_sum += new_weight

	weights = new_weights
	nonzero_indexes = new_nonzero_indexes

/// Gets the indexes of this step's tiles that are next to a tile with weight from the last step, in order
/datum/radiation_wave/proc/get_indexes_to_check(edge_length, ring_length)
	. = list()
	// The first step spreads the source tile to all 8 tiles around it
	if(steps == 1)
		for(var/i in 1 to ring_length)
			. += i
		return
	var/last_edge_length = edge_length - 2
	var/last_added = 0
	for(var/last_index in nonzero_indexes)
		var/edge = floor((last_index - 1) / last_edge_length)
		// Each edge gets 2 tiles longer, so this is the same spot on the new edge. It reaches that tile and the 2 after it.
		var/first = last_index + 2 * edge
		var/start = first
		// The first tile of an edge also reaches the 2 tiles before the corner
		if(edge > 0 && last_index - edge * last_edge_length == 1)
			start = first - 2
		for(var/i in max(start, last_added + 1) to first + 2)
			. += i
		last_added = first + 2
	// The very first tile wraps around to the end of the ring too
	if(length(nonzero_indexes) && nonzero_indexes[1] == 1)
		for(var/i in max(ring_length - 1, last_added + 1) to ring_length)
			. += i

/// Calls rad act on each relevant atom in the turf and returns the resulting weight for that tile after reduction by insulation
/datum/radiation_wave/proc/radiate(atom/source, turf/current_turf, weight, emission_type, list/turf_atoms_cache)
	// populate cache if needed
	var/list/turf_atoms = turf_atoms_cache[current_turf]
	if(!turf_atoms)
		turf_atoms = get_rad_contents(current_turf, emission_type)
		turf_atoms_cache[current_turf] = turf_atoms

	for(var/k in turf_atoms)
		var/atom/thing = k
		if(QDELETED(thing))
			continue
		weight = weight * thing.base_rad_act(source ,weight * intensity, emission_type)
	// return the resulting weight if the radiation on the tile would end up greater than background
	return (((weight * intensity) > RAD_BACKGROUND_RADIATION) ? weight : 0)

#undef WRAP_INDEX
