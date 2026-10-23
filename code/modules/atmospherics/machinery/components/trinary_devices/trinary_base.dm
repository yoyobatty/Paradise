/obj/machinery/atmospherics/trinary
	initialize_directions = SOUTH|NORTH|WEST
	power_state = IDLE_POWER_USE

	layer = GAS_PIPE_VISIBLE_LAYER + GAS_FILTER_OFFSET
	layer_offset = GAS_FILTER_OFFSET
	device_type = TRINARY

	var/flipped = FALSE

/obj/machinery/atmospherics/trinary/New()
	parents = new /list(device_type)
	..()

	if(!flipped)
		switch(dir)
			if(NORTH)
				initialize_directions = EAST|NORTH|SOUTH
			if(SOUTH)
				initialize_directions = SOUTH|WEST|NORTH
			if(EAST)
				initialize_directions = EAST|WEST|SOUTH
			if(WEST)
				initialize_directions = WEST|NORTH|EAST
	else
		switch(dir)
			if(NORTH)
				initialize_directions = SOUTH|NORTH|WEST
			if(SOUTH)
				initialize_directions = NORTH|SOUTH|EAST
			if(EAST)
				initialize_directions = WEST|EAST|NORTH
			if(WEST)
				initialize_directions = EAST|WEST|SOUTH

	create_device_airs()

/obj/machinery/atmospherics/trinary/get_node_connects()
	//Mixer:
	//1 and 2 is input
	//Node 3 is output
	//If we flip the mixer, 1 and 3 shall exchange positions

	//Filter:
	//Node 1 is input
	//Node 2 is filtered output
	//Node 3 is rest output
	//If we flip the filter, 1 and 3 shall exchange positions

	var/node1_connect = turn(dir, -180)
	var/node2_connect = turn(dir, -90)
	var/node3_connect = dir

	if(flipped)
		node2_connect = turn(node2_connect, -180)

	return list(node1_connect, node2_connect, node3_connect)

// Trinary devices plug into anything facing them, whatever its connect type
/obj/machinery/atmospherics/trinary/find_node(direction, end)
	for(var/obj/machinery/atmospherics/target in get_step(src, direction))
		if(target.initialize_directions & get_dir(target, src))
			return target
