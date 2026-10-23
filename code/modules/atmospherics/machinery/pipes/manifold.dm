/obj/machinery/atmospherics/pipe/manifold
	icon = 'icons/atmos/manifold.dmi'
	icon_state = ""
	name = "pipe manifold"
	desc = "A manifold composed of regular pipes."

	volume = 105

	initialize_directions = EAST|NORTH|WEST
	device_type = TRINARY

	level = 1

/obj/machinery/atmospherics/pipe/manifold/New()
	..()

	alpha = 255
	icon = null
	switch(dir)
		if(NORTH)
			initialize_directions = EAST|SOUTH|WEST
		if(SOUTH)
			initialize_directions = WEST|NORTH|EAST
		if(EAST)
			initialize_directions = SOUTH|WEST|NORTH
		if(WEST)
			initialize_directions = NORTH|EAST|SOUTH

/obj/machinery/atmospherics/pipe/manifold/examine(mob/user)
	. = ..()
	. += SPAN_NOTICE("A pipe with three ends to connect to.")

/obj/machinery/atmospherics/pipe/manifold/get_node_connects()
	return list(turn(dir, 90), turn(dir, 270), turn(dir, 180))

/obj/machinery/atmospherics/pipe/manifold/atmos_init()
	..()
	connect_nodes()
	var/turf/T = src.loc			// hide if turf is not intact
	if(T.transparent_floor)
		return
	hide(T.intact)
	update_icon()

/obj/machinery/atmospherics/pipe/manifold/hide(i)
	if(level == 1 && issimulatedturf(loc))
		invisibility = i ? INVISIBILITY_MAXIMUM : 0

/obj/machinery/atmospherics/pipe/manifold/update_overlays()
	. = ..()
	alpha = 255
	. += GLOB.pipe_icon_manager.get_atmos_icon("manifold", null, pipe_color, "core" + icon_connect_type)
	. += GLOB.pipe_icon_manager.get_atmos_icon("manifold", null, null, "clamps" + icon_connect_type)
	update_underlays()

/obj/machinery/atmospherics/pipe/manifold/update_underlays()
	underlays.Cut()

	var/turf/T = get_turf(src)
	if(!istype(T)) return
	var/list/directions = list(NORTH, SOUTH, EAST, WEST)
	var/node1_direction = get_dir(src, nodes[1])
	var/node2_direction = get_dir(src, nodes[2])
	var/node3_direction = get_dir(src, nodes[3])

	directions -= dir

	directions -= add_underlay(T,nodes[1],node1_direction,icon_connect_type)
	directions -= add_underlay(T,nodes[2],node2_direction,icon_connect_type)
	directions -= add_underlay(T,nodes[3],node3_direction,icon_connect_type)

	for(var/D in directions)
		add_underlay(T, null,D,icon_connect_type)

/obj/machinery/atmospherics/pipe/manifold/visible
	icon_state = "map"
	level = 2
	layer = GAS_PIPE_VISIBLE_LAYER

/obj/machinery/atmospherics/pipe/manifold/visible/scrubbers
	name="Scrubbers pipe manifold"
	desc = "A manifold composed of scrubbers pipes."
	icon_state = "map-scrubbers"
	connect_types = list(CONNECT_TYPE_SCRUBBER)
	layer = GAS_PIPE_VISIBLE_LAYER + GAS_PIPE_SCRUB_OFFSET
	layer_offset = GAS_PIPE_SCRUB_OFFSET
	icon_connect_type = "-scrubbers"
	color = PIPE_COLOR_RED

/obj/machinery/atmospherics/pipe/manifold/visible/scrubbers/examine(mob/user)
	. = ..()
	. += SPAN_NOTICE("This is a special 'scrubber' pipe, which does not connect to 'normal' pipes. If you want to connect it, use \
			a Universal Pipe Adapter.")

/obj/machinery/atmospherics/pipe/manifold/visible/supply
	name="Air supply pipe manifold"
	desc = "A manifold composed of supply pipes."
	icon_state = "map-supply"
	connect_types = list(CONNECT_TYPE_SUPPLY)
	layer = GAS_PIPE_VISIBLE_LAYER + GAS_PIPE_SUPPLY_OFFSET
	layer_offset = GAS_PIPE_SUPPLY_OFFSET
	icon_connect_type = "-supply"
	color = PIPE_COLOR_BLUE

/obj/machinery/atmospherics/pipe/manifold/visible/supply/examine(mob/user)
	. = ..()
	. += SPAN_NOTICE("This is a special 'supply' pipe, which does not connect to 'normal' pipes. If you want to connect it, use \
			a Universal Pipe Adapter.")

/obj/machinery/atmospherics/pipe/manifold/visible/yellow
	color = PIPE_COLOR_YELLOW

/obj/machinery/atmospherics/pipe/manifold/visible/cyan
	color = PIPE_COLOR_CYAN

/obj/machinery/atmospherics/pipe/manifold/visible/green
	color = PIPE_COLOR_GREEN

/obj/machinery/atmospherics/pipe/manifold/visible/purple
	color = PIPE_COLOR_PURPLE

/obj/machinery/atmospherics/pipe/manifold/visible/red
	color = PIPE_COLOR_RED

/obj/machinery/atmospherics/pipe/manifold/visible/blue
	color = PIPE_COLOR_BLUE

/obj/machinery/atmospherics/pipe/manifold/hidden
	icon_state = "map"
	alpha = 128		//set for the benefit of mapping - this is reset to opaque when the pipe is spawned in game
	plane = FLOOR_PLANE

/obj/machinery/atmospherics/pipe/manifold/hidden/scrubbers
	name="Scrubbers pipe manifold"
	desc = "A manifold composed of scrubbers pipes."
	icon_state = "map-scrubbers"
	connect_types = list(CONNECT_TYPE_SCRUBBER)
	layer = GAS_PIPE_HIDDEN_LAYER + GAS_PIPE_SCRUB_OFFSET
	layer_offset = GAS_PIPE_SCRUB_OFFSET
	icon_connect_type = "-scrubbers"
	color = PIPE_COLOR_RED

/obj/machinery/atmospherics/pipe/manifold/hidden/scrubbers/examine(mob/user)
	. = ..()
	. += SPAN_NOTICE("This is a special 'scrubber' pipe, which does not connect to 'normal' pipes. If you want to connect it, use \
			a Universal Pipe Adapter.")

/obj/machinery/atmospherics/pipe/manifold/hidden/supply
	name="Air supply pipe manifold"
	desc = "A manifold composed of supply pipes."
	icon_state = "map-supply"
	connect_types = list(CONNECT_TYPE_SUPPLY)
	layer = GAS_PIPE_HIDDEN_LAYER + GAS_PIPE_SUPPLY_OFFSET
	layer_offset = GAS_PIPE_SUPPLY_OFFSET
	icon_connect_type = "-supply"
	color = PIPE_COLOR_BLUE

/obj/machinery/atmospherics/pipe/manifold/hidden/supply/examine(mob/user)
	. = ..()
	. += SPAN_NOTICE("This is a special 'supply' pipe, which does not connect to 'normal' pipes. If you want to connect it, use \
			a Universal Pipe Adapter.")

/obj/machinery/atmospherics/pipe/manifold/hidden/yellow
	color = PIPE_COLOR_YELLOW

/obj/machinery/atmospherics/pipe/manifold/hidden/cyan
	color = PIPE_COLOR_CYAN

/obj/machinery/atmospherics/pipe/manifold/hidden/green
	color = PIPE_COLOR_GREEN

/obj/machinery/atmospherics/pipe/manifold/hidden/purple
	color = PIPE_COLOR_PURPLE

/obj/machinery/atmospherics/pipe/manifold/hidden/red
	color = PIPE_COLOR_RED

/obj/machinery/atmospherics/pipe/manifold/hidden/blue
	color = PIPE_COLOR_BLUE
