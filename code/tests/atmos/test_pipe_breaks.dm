/datum/game_test/room_test/pipe_breaks
	var/turf/origin

/datum/game_test/room_test/pipe_breaks/proc/put(type, x, y, dir, connects)
	var/obj/machinery/atmospherics/A = new type(locate(origin.x + x, origin.y + y, origin.z))
	A.on_construction(dir, connects)
	return A

/datum/game_test/room_test/pipe_breaks/Run()
	origin = available_turfs[1]
	// A loop through a pump, with a vent off a manifold at the top
	var/obj/machinery/atmospherics/binary/pump/pump = put(/obj/machinery/atmospherics/binary/pump, 2, 1, EAST, EAST|WEST)
	var/obj/machinery/atmospherics/pipe/left_bottom = put(/obj/machinery/atmospherics/pipe/simple/visible, 1, 1, NORTHEAST, NORTH|EAST)
	put(/obj/machinery/atmospherics/pipe/simple/visible, 1, 2, NORTH, NORTH|SOUTH)
	put(/obj/machinery/atmospherics/pipe/simple/visible, 1, 3, SOUTHEAST, SOUTH|EAST)
	var/obj/machinery/atmospherics/pipe/manifold = put(/obj/machinery/atmospherics/pipe/manifold/visible, 2, 3, SOUTH, NORTH|EAST|WEST)
	var/obj/machinery/atmospherics/unary/vent = put(/obj/machinery/atmospherics/unary/passive_vent, 2, 4, SOUTH, SOUTH)
	put(/obj/machinery/atmospherics/pipe/simple/visible, 3, 3, SOUTHWEST, SOUTH|WEST)
	var/obj/machinery/atmospherics/pipe/right_middle = put(/obj/machinery/atmospherics/pipe/simple/visible, 3, 2, NORTH, NORTH|SOUTH)
	put(/obj/machinery/atmospherics/pipe/simple/visible, 3, 1, NORTHWEST, NORTH|WEST)

	var/datum/pipeline/loop = pump.parent1
	TEST_ASSERT_NOTNULL(loop, "pump has no pipenet")
	TEST_ASSERT_EQUAL(pump.parent2, loop, "both pump sides should be on the loop")
	TEST_ASSERT_EQUAL(vent.parent, loop, "vent should be on the loop")
	TEST_ASSERT_EQUAL(length(loop.members), 7, "loop pipe count")
	loop.air.set_oxygen(105)

	// Cut the loop on the left
	qdel(locate(/obj/machinery/atmospherics/pipe) in locate(origin.x + 1, origin.y + 2, origin.z))
	// No waiting for atmos to rebuild anything
	TEST_ASSERT_NOTNULL(pump.parent1, "pump input lost its pipenet")
	TEST_ASSERT_NOTNULL(pump.parent2, "pump output lost its pipenet")
	TEST_ASSERT_NOTEQUAL(pump.parent1, pump.parent2, "pump sides should be apart now")
	TEST_ASSERT_EQUAL(left_bottom.parent, pump.parent1, "pipe under the cut should be on the pump input")
	TEST_ASSERT_EQUAL(right_middle.parent, pump.parent2, "right side should be on the pump output")
	TEST_ASSERT_EQUAL(vent.parent, pump.parent2, "vent should be on the pump output")
	TEST_ASSERT_EQUAL(length(pump.parent1.members), 1, "input piece pipe count")
	TEST_ASSERT_EQUAL(length(pump.parent2.members), 5, "output piece pipe count")
	TEST_ASSERT_EQUAL(length(pump.parent1.other_airs), 1, "input piece should share the pump input only")
	TEST_ASSERT(pump.air1 in pump.parent1.other_airs, "input piece should share the pump input")
	TEST_ASSERT(!(pump.air1 in pump.parent2.other_airs), "output piece shouldn't share the pump input")
	TEST_ASSERT(pump.air2 in pump.parent2.other_airs, "output piece should share the pump output")
	// Each piece keeps its share of the gas, the broken pipe's share goes with it
	TEST_ASSERT(abs(pump.parent1.air.oxygen() - 105 * 70 / 525) < 0.01, "input piece gas [pump.parent1.air.oxygen()]")
	TEST_ASSERT(abs(pump.parent2.air.oxygen() - 105 * 385 / 525) < 0.01, "output piece gas [pump.parent2.air.oxygen()]")

	// Build it back
	put(/obj/machinery/atmospherics/pipe/simple/visible, 1, 2, NORTH, NORTH|SOUTH)
	TEST_ASSERT_EQUAL(pump.parent1, pump.parent2, "pump sides should be joined again")
	TEST_ASSERT_EQUAL(length(pump.parent1.members), 7, "loop pipe count after building it back")
	TEST_ASSERT_EQUAL(length(pump.parent1.other_atmosmch), 2, "pump and vent, each listed once")

	// Break the manifold the vent hangs off, that cuts the loop at the top
	qdel(manifold)
	TEST_ASSERT_NOTNULL(vent.parent, "vent lost its pipenet")
	TEST_ASSERT_EQUAL(length(vent.parent.members), 0, "vent should be on a pipenet of its own")
	TEST_ASSERT_EQUAL(length(vent.parent.other_atmosmch), 1, "vent should be on a pipenet of its own")
	TEST_ASSERT(!(vent in pump.parent1.other_atmosmch) && !(vent in pump.parent2.other_atmosmch), "vent should be off the pump's pipenets")
	TEST_ASSERT_NOTEQUAL(pump.parent1, pump.parent2, "pump sides should be apart again")
	TEST_ASSERT_EQUAL(length(pump.parent1.members), 3, "input piece pipe count after the manifold")
	TEST_ASSERT_EQUAL(length(pump.parent2.members), 3, "output piece pipe count after the manifold")
