GLOBAL_DATUM_INIT(apc_repository, /datum/repository/apc, new())

/datum/repository/apc/New()
	cache_data = list()
	..()

/datum/repository/apc/proc/apc_data(datum/regional_powernet/powernet)
	var/apcData[0]

	// Power monitors on different grids see different APCs, so each powernet gets its own list.
	var/cache_key = "[powernet?.UID()]"
	var/datum/cache_entry/cache_entry = cache_data[cache_key]
	if(!cache_entry)
		// Powernets are remade whenever cables are cut or joined, so drop the lists that have run out first.
		for(var/old_key in cache_data)
			var/datum/cache_entry/old_entry = cache_data[old_key]
			if(world.time >= old_entry.timestamp)
				cache_data -= old_key
		cache_entry = new/datum/cache_entry
		cache_data[cache_key] = cache_entry

	if(world.time < cache_entry.timestamp)
		return cache_entry.data

	if(powernet)
		var/list/L = list()
		for(var/obj/machinery/power/terminal/term in powernet.nodes)
			if(istype(term.master, /obj/machinery/power/apc))
				var/obj/machinery/power/apc/A = term.master
				L += A

		var/list/Status = list("Off","AOff","On","AOn") // Status:  off, auto-off, on, auto-on
		var/list/chg = list("N","C","F") // Charging: no, charging, full
		for(var/obj/machinery/power/apc/A in L)
			apcData[++apcData.len] = list(
				"Name" = html_encode(A.apc_area.name),
				"Equipment" = Status[A.equipment_channel + 1],
				"Lights" = Status[A.lighting_channel + 1],
				"Environment" = Status[A.environment_channel + 1],
				"CellPct" = A.cell ? round(A.cell.percent(), 1) : 0,
				"CellStatus" = A.cell ? chg[A.charging + 1] : "M",
				"Load" = round(A.last_used_total, 1)
			)

	cache_entry.timestamp = world.time + 5 SECONDS
	cache_entry.data = apcData
	return apcData
