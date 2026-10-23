/obj/machinery/atmospherics/pipe/simple
	name = "pipe"
	desc = "A one meter section of regular pipe."
	icon = 'icons/atmos/pipes.dmi'
	icon_state = ""
	var/pipe_icon = "" //what kind of pipe it is and from which dmi is the icon manager getting its icons, "" for simple pipes, "hepipe" for HE pipes, "hejunction" for HE junctions

	volume = 70

	initialize_directions = SOUTH|NORTH
	device_type = BINARY

	var/minimum_temperature_difference = 300
	var/thermal_conductivity = 0 //WALL_HEAT_TRANSFER_COEFFICIENT No

	level = 1

/obj/machinery/atmospherics/pipe/simple/New()
	..()
	// Pipe colors and icon states are handled by an image cache - so color and icon should
	//  be null. For mapping purposes color is defined in the object definitions.
	icon = null
	alpha = 255

	switch(dir)
		if(SOUTH, NORTH)
			initialize_directions = SOUTH|NORTH
		if(EAST, WEST)
			initialize_directions = EAST|WEST
		if(NORTHEAST)
			initialize_directions = NORTH|EAST
		if(NORTHWEST)
			initialize_directions = NORTH|WEST
		if(SOUTHEAST)
			initialize_directions = SOUTH|EAST
		if(SOUTHWEST)
			initialize_directions = SOUTH|WEST

/obj/machinery/atmospherics/pipe/simple/atmos_init(initPipe = 1)
	..()
	if(initPipe)
		normalize_dir()
		connect_nodes(keep_nodes = TRUE)

		var/turf/T = loc			// hide if turf is not intact
		if(!T.transparent_floor)
			hide(T.intact)
		update_icon()

/obj/machinery/atmospherics/pipe/simple/proc/burst()
	src.visible_message(SPAN_DANGER("\The [src] bursts!"))
	playsound(src.loc, 'sound/effects/bang.ogg', 25, 1)
	var/datum/effect_system/smoke_spread/smoke = new
	smoke.set_up(1, FALSE, loc)
	smoke.start()
	qdel(src)

/obj/machinery/atmospherics/pipe/simple/proc/normalize_dir()
	if(dir==3)
		dir = NORTH
	else if(dir==12)
		dir = EAST

/obj/machinery/atmospherics/pipe/simple/get_node_connects(directions = initialize_directions)
	. = list()
	for(var/D in GLOB.cardinal)
		if(D & directions)
			. += D

/obj/machinery/atmospherics/pipe/simple/update_overlays()
	. = ..()
	alpha = 255
	if(nodes[1] && nodes[2])
		. += GLOB.pipe_icon_manager.get_atmos_icon("pipe", null, pipe_color, pipe_icon + "intact" + icon_connect_type)
	else
		. += GLOB.pipe_icon_manager.get_atmos_icon("pipe", null, pipe_color, pipe_icon + "exposed[nodes[1] ? 1 : 0][nodes[2] ? 1 : 0]" + icon_connect_type)

/obj/machinery/atmospherics/pipe/simple/update_underlays()
	return

/obj/machinery/atmospherics/pipe/simple/hide(i)
	if(level == 1 && issimulatedturf(loc))
		invisibility = i ? INVISIBILITY_MAXIMUM : 0
