/// A volume pump moves the share of its input its rate asks for, and no more.
/datum/game_test/volume_pump_rate

/datum/game_test/volume_pump_rate/Run()
	var/obj/machinery/atmospherics/binary/volume_pump/pump = allocate(/obj/machinery/atmospherics/binary/volume_pump)
	// Pipe networks of its own, so it has something to tell when its air changes
	pump.parent1 = allocate(/datum/pipeline)
	pump.parent2 = allocate(/datum/pipeline)
	pump.stat = NONE
	pump.on = TRUE
	for(var/rate in list(0, 50, 200))
		pump.transfer_rate = rate
		pump.air1.set_oxygen(100)
		pump.air1.set_temperature(T20C)
		pump.air2.set_oxygen(0)
		pump.process_atmos()
		TEST_ASSERT_EQUAL(pump.air2.oxygen(), 100 * rate / pump.air1.volume, "A volume pump set to [rate] L/s moved the wrong amount out of a [pump.air1.volume] L input holding 100 moles.")
