/obj/machinery/atmospherics/unary/portables_connector
	icon = 'icons/atmos/connector.dmi'
	icon_state = "map_connector"

	name = "connector port"
	desc = "For connecting portables devices related to atmospherics control."

	can_unwrench = TRUE
	adds_to_air_share = TRUE
	layer = GAS_PIPE_VISIBLE_LAYER + GAS_FILTER_OFFSET
	layer_offset = GAS_FILTER_OFFSET

	var/obj/machinery/atmospherics/portable/connected_device

/obj/machinery/atmospherics/unary/portables_connector/Destroy()
	if(connected_device)
		connected_device.disconnect()
	return ..()

/obj/machinery/atmospherics/unary/portables_connector/update_icon_state()
	icon_state = "connector"

/obj/machinery/atmospherics/unary/portables_connector/update_underlays()
	if(..())
		underlays.Cut()
		var/turf/T = get_turf(src)
		if(!istype(T))
			return
		add_underlay(T, nodes[1], dir)

/obj/machinery/atmospherics/unary/portables_connector/add_to_air_share(datum/pipeline/root, list/pipelines, list/mixtures)
	// Whatever's plugged in shares its gas with our pipenet
	if(connected_device)
		mixtures += portableConnectorReturnAir()

/obj/machinery/atmospherics/unary/portables_connector/process_atmos()
	if(!connected_device)
		return 0
	update_parents()

/obj/machinery/atmospherics/unary/portables_connector/wrench_act(mob/living/user, obj/item/wrench/W)
	if(connected_device)
		to_chat(user, SPAN_DANGER("You cannot unwrench this [name], detach [connected_device] first."))
		return TRUE
	return ..()

/obj/machinery/atmospherics/unary/portables_connector/portableConnectorReturnAir()
	return connected_device.portableConnectorReturnAir()

/obj/proc/portableConnectorReturnAir()
	return
