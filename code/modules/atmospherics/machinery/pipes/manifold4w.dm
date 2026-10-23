/obj/machinery/atmospherics/pipe/manifold4w
	icon = 'icons/atmos/manifold.dmi'
	icon_state = ""
	name = "4-way pipe manifold"
	desc = "A manifold composed of regular pipes."

	volume = 140

	initialize_directions = NORTH|SOUTH|EAST|WEST
	device_type = QUATERNARY

	level = 1

/obj/machinery/atmospherics/pipe/manifold4w/New()
	..()
	alpha = 255
	icon = null

/obj/machinery/atmospherics/pipe/manifold4w/examine(mob/user)
	. = ..()
	. += SPAN_NOTICE("This is a normal pipe with 4 connecting ends.")

/obj/machinery/atmospherics/pipe/manifold4w/update_overlays()
	. = ..()
	alpha = 255
	. += GLOB.pipe_icon_manager.get_atmos_icon("manifold", null, pipe_color, "4way" + icon_connect_type)
	. += GLOB.pipe_icon_manager.get_atmos_icon("manifold", null, null, "clamps_4way" + icon_connect_type)
	update_underlays()

/obj/machinery/atmospherics/pipe/manifold4w/update_underlays()
	underlays.Cut()

	var/turf/T = get_turf(src)
	if(!istype(T)) return
	var/list/directions = list(NORTH, SOUTH, EAST, WEST)
	var/node1_direction = get_dir(src, nodes[1])
	var/node2_direction = get_dir(src, nodes[2])
	var/node3_direction = get_dir(src, nodes[3])
	var/node4_direction = get_dir(src, nodes[4])

	directions -= dir

	directions -= add_underlay(T,nodes[1],node1_direction,icon_connect_type)
	directions -= add_underlay(T,nodes[2],node2_direction,icon_connect_type)
	directions -= add_underlay(T,nodes[3],node3_direction,icon_connect_type)
	directions -= add_underlay(T,nodes[4],node4_direction,icon_connect_type)

	for(var/D in directions)
		add_underlay(T, null,D,icon_connect_type)

/obj/machinery/atmospherics/pipe/manifold4w/hide(i)
	if(level == 1 && issimulatedturf(loc))
		invisibility = i ? INVISIBILITY_MAXIMUM : 0

/obj/machinery/atmospherics/pipe/manifold4w/get_node_connects()
	return list(NORTH, SOUTH, EAST, WEST)

/obj/machinery/atmospherics/pipe/manifold4w/atmos_init()
	..()
	connect_nodes()

	var/turf/T = src.loc			// hide if turf is not intact
	if(!T.transparent_floor)
		hide(T.intact)
	update_icon()

/obj/machinery/atmospherics/pipe/manifold4w/visible
	icon_state = "map_4way"
	level = 2
	layer = GAS_PIPE_VISIBLE_LAYER

/obj/machinery/atmospherics/pipe/manifold4w/visible/scrubbers
	name="4-way scrubbers pipe manifold"
	desc = "A manifold composed of scrubbers pipes."
	icon_state = "map_4way-scrubbers"
	connect_types = list(CONNECT_TYPE_SCRUBBER)
	layer = GAS_PIPE_VISIBLE_LAYER + GAS_PIPE_SCRUB_OFFSET
	layer_offset = GAS_PIPE_SCRUB_OFFSET
	icon_connect_type = "-scrubbers"
	color = PIPE_COLOR_RED

/obj/machinery/atmospherics/pipe/manifold4w/visible/scrubbers/examine(mob/user)
	. = ..()
	. += SPAN_NOTICE("This is a special 'scrubber' pipe, which does not connect to 'normal' pipes.  If you want to connect it, use \
	a Universal Pipe Adapter.")

/obj/machinery/atmospherics/pipe/manifold4w/visible/supply
	name="4-way air supply pipe manifold"
	desc = "A manifold composed of supply pipes."
	icon_state = "map_4way-supply"
	connect_types = list(CONNECT_TYPE_SUPPLY)
	layer = GAS_PIPE_VISIBLE_LAYER + GAS_PIPE_SUPPLY_OFFSET
	layer_offset = GAS_PIPE_SUPPLY_OFFSET
	icon_connect_type = "-supply"
	color = PIPE_COLOR_BLUE

/obj/machinery/atmospherics/pipe/manifold4w/visible/supply/examine(mob/user)
	. = ..()
	. += SPAN_NOTICE("This is a special 'supply' pipe, which does not connect to 'normal' pipes.  If you want to connect it, use \
	a Universal Pipe Adapter.")

/obj/machinery/atmospherics/pipe/manifold4w/visible/yellow
	color = PIPE_COLOR_YELLOW

/obj/machinery/atmospherics/pipe/manifold4w/visible/cyan
	color = PIPE_COLOR_CYAN

/obj/machinery/atmospherics/pipe/manifold4w/visible/green
	color = PIPE_COLOR_GREEN

/obj/machinery/atmospherics/pipe/manifold4w/visible/purple
	color = PIPE_COLOR_PURPLE

/obj/machinery/atmospherics/pipe/manifold4w/hidden
	icon_state = "map_4way"
	alpha = 128		//set for the benefit of mapping - this is reset to opaque when the pipe is spawned in game
	plane = FLOOR_PLANE

/obj/machinery/atmospherics/pipe/manifold4w/hidden/scrubbers
	name = "4-way scrubbers pipe manifold"
	desc = "A manifold composed of scrubbers pipes."
	icon_state = "map_4way-scrubbers"
	connect_types = list(CONNECT_TYPE_SCRUBBER)
	layer = GAS_PIPE_HIDDEN_LAYER + GAS_PIPE_SCRUB_OFFSET
	layer_offset = GAS_PIPE_SCRUB_OFFSET
	icon_connect_type = "-scrubbers"
	color = PIPE_COLOR_RED

/obj/machinery/atmospherics/pipe/manifold4w/hidden/scrubbers/examine(mob/user)
	. = ..()
	. += SPAN_NOTICE("This is a special 'scrubber' pipe, which does not connect to 'normal' pipes.  If you want to connect it, use \
	a Universal Pipe Adapter.")

/obj/machinery/atmospherics/pipe/manifold4w/hidden/supply
	name = "4-way air supply pipe manifold"
	desc = "A manifold composed of supply pipes."
	icon_state = "map_4way-supply"
	connect_types = list(CONNECT_TYPE_SUPPLY)
	layer = GAS_PIPE_HIDDEN_LAYER + GAS_PIPE_SUPPLY_OFFSET
	layer_offset = GAS_PIPE_SUPPLY_OFFSET
	icon_connect_type = "-supply"
	color = PIPE_COLOR_BLUE

/obj/machinery/atmospherics/pipe/manifold4w/hidden/supply/examine(mob/user)
	. = ..()
	. += SPAN_NOTICE("This is a special 'supply' pipe, which does not connect to 'normal' pipes.  If you want to connect it, use \
	a Universal Pipe Adapter.")

/obj/machinery/atmospherics/pipe/manifold4w/hidden/yellow
	color = PIPE_COLOR_YELLOW

/obj/machinery/atmospherics/pipe/manifold4w/hidden/cyan
	color = PIPE_COLOR_CYAN

/obj/machinery/atmospherics/pipe/manifold4w/hidden/green
	color = PIPE_COLOR_GREEN

/obj/machinery/atmospherics/pipe/manifold4w/hidden/purple
	color = PIPE_COLOR_PURPLE
