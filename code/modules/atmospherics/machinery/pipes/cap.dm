/obj/machinery/atmospherics/pipe/cap
	name = "pipe endcap"
	desc = "An endcap for pipes."
	icon = 'icons/atmos/pipes.dmi'
	icon_state = "cap"

	volume = 35

	initialize_directions = SOUTH
	device_type = UNARY

/obj/machinery/atmospherics/pipe/cap/New()
	..()
	initialize_directions = dir

/obj/machinery/atmospherics/pipe/cap/examine(mob/user)
	. = ..()
	. += SPAN_NOTICE("Largely cosmetic as pipes automatically seal themselves off from leaking gases if not connected to another pipe. Will prevent a nasty ventcrawler from paying you a visit however.")

/obj/machinery/atmospherics/pipe/cap/hide(i)
	if(level == 1 && issimulatedturf(loc))
		invisibility = i ? INVISIBILITY_MAXIMUM : 0
	update_icon()

/obj/machinery/atmospherics/pipe/cap/process_atmos()
	if(!parent)
		..()
	else
		. = PROCESS_KILL

// Caps stay put even with nothing on their end
/obj/machinery/atmospherics/pipe/cap/check_nodes_exist()
	return

/obj/machinery/atmospherics/pipe/cap/update_overlays()
	. = ..()
	alpha = 255
	. += GLOB.pipe_icon_manager.get_atmos_icon("pipe", null, pipe_color, "cap" + icon_connect_type)

/obj/machinery/atmospherics/pipe/cap/get_node_connects()
	return list(dir)

/obj/machinery/atmospherics/pipe/cap/atmos_init()
	..()
	connect_nodes()

	var/turf/T = get_turf(src)			// hide if turf is not intact
	if(!istype(T) || T.transparent_floor)
		return
	hide(T.intact)
	update_icon()

/obj/machinery/atmospherics/pipe/cap/visible
	layer = GAS_PIPE_VISIBLE_LAYER

/obj/machinery/atmospherics/pipe/cap/visible/scrubbers
	name = "scrubbers pipe endcap"
	desc = "An endcap for scrubbers pipes."
	icon_state = "cap-scrubbers"
	connect_types = list(CONNECT_TYPE_SCRUBBER)
	layer = GAS_PIPE_VISIBLE_LAYER + GAS_PIPE_SCRUB_OFFSET
	layer_offset = GAS_PIPE_SCRUB_OFFSET
	icon_connect_type = "-scrubbers"
	color = PIPE_COLOR_RED

/obj/machinery/atmospherics/pipe/cap/visible/supply
	name = "supply pipe endcap"
	desc = "An endcap for supply pipes."
	icon_state = "cap-supply"
	connect_types = list(CONNECT_TYPE_SUPPLY)
	layer = GAS_PIPE_VISIBLE_LAYER + GAS_PIPE_SUPPLY_OFFSET
	layer_offset = GAS_PIPE_SUPPLY_OFFSET
	icon_connect_type = "-supply"
	color = PIPE_COLOR_BLUE

/obj/machinery/atmospherics/pipe/cap/hidden
	level = 1
	alpha = 128
	plane = FLOOR_PLANE

/obj/machinery/atmospherics/pipe/cap/hidden/scrubbers
	name = "scrubbers pipe endcap"
	desc = "An endcap for scrubbers pipes."
	icon_state = "cap-scrubbers"
	connect_types = list(CONNECT_TYPE_SCRUBBER)
	layer = GAS_PIPE_HIDDEN_LAYER + GAS_PIPE_SCRUB_OFFSET
	layer_offset = GAS_PIPE_SCRUB_OFFSET
	icon_connect_type = "-scrubbers"
	color = PIPE_COLOR_RED

/obj/machinery/atmospherics/pipe/cap/hidden/supply
	name = "supply pipe endcap"
	desc = "An endcap for supply pipes."
	icon_state = "cap-supply"
	connect_types = list(CONNECT_TYPE_SUPPLY)
	layer = GAS_PIPE_HIDDEN_LAYER + GAS_PIPE_SUPPLY_OFFSET
	layer_offset = GAS_PIPE_SUPPLY_OFFSET
	icon_connect_type = "-supply"
	color = PIPE_COLOR_BLUE
