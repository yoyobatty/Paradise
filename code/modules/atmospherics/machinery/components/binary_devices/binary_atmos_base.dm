/obj/machinery/atmospherics/binary
	initialize_directions = SOUTH|NORTH
	power_state = IDLE_POWER_USE

	layer = GAS_PIPE_VISIBLE_LAYER + GAS_PUMP_OFFSET
	layer_offset = GAS_PUMP_OFFSET
	device_type = BINARY

/obj/machinery/atmospherics/binary/New()
	parents = new /list(device_type)
	..()
	switch(dir)
		if(NORTH)
			initialize_directions = NORTH|SOUTH
		if(SOUTH)
			initialize_directions = NORTH|SOUTH
		if(EAST)
			initialize_directions = EAST|WEST
		if(WEST)
			initialize_directions = EAST|WEST

	create_device_airs()

/obj/machinery/atmospherics/binary/get_node_connects()
	return list(turn(dir, 180), dir)
