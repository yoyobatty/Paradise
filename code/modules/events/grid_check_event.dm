/// How many APCs get their breaker flipped each tick. All of them in one go froze the server for about a fifth of a second.
#define GRID_CHECK_APCS_PER_TICK 5

/datum/event/grid_check
	name = "Grid Check"
	nominal_severity = EVENT_LEVEL_MODERATE
	endWhen = 60 // In process ticks

/datum/event/grid_check/announce(false_alarm)
	GLOB.minor_announcement.Announce("Abnormal activity detected in [station_name()]'s powernet. As a precautionary measure, the station's power will be shut off for an indeterminate duration.", "Electrical Grid Check")
	return

/datum/event/grid_check/start()
	. = ..()
	addtimer(CALLBACK(src, PROC_REF(toggle_power)), rand(10 SECONDS, 15 SECONDS))

/datum/event/grid_check/proc/toggle_power(state = TRUE)
	var/list/skipped_areas_apc = list(
		/area/station/turret_protected/ai,
		/area/station/command/office/ce)
	skipped_areas_apc += subtypesof(/area/station/engineering)
	skipped_areas_apc += subtypesof(/area/station/telecomms)
	var/list/to_toggle = list()
	for(var/obj/machinery/power/apc/power_controller in GLOB.apcs)
		var/area/current_area = get_area(power_controller)
		if((current_area.type in skipped_areas_apc) || !is_station_level(power_controller.z))
			continue
		if(power_controller.operating == state)
			to_toggle += power_controller
	for(var/mob/M in GLOB.player_list)
		var/turf/T = get_turf(M)
		if(!M.client || !is_station_level(T.z) || isnewplayer(M))
			continue
		if(state)
			SEND_SOUND(M, sound('sound/effects/powerloss.ogg'))
		else
			SEND_SOUND(M, sound('sound/mecha/powerup.ogg'))

	if(state)
		addtimer(CALLBACK(src, PROC_REF(toggle_power), FALSE), rand(30 SECONDS, 120 SECONDS))

	// A few at a time, so the power goes out (or comes back) across the station over a second or two
	var/flipped = 0
	for(var/obj/machinery/power/apc/power_controller as anything in to_toggle)
		if(QDELETED(power_controller) || power_controller.operating != state)
			continue
		power_controller.toggle_breaker()
		if(++flipped % GRID_CHECK_APCS_PER_TICK == 0)
			sleep(world.tick_lag)

#undef GRID_CHECK_APCS_PER_TICK
