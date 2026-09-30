/// Deleted station pets have to leave GLOB.station_pets, or they hard delete and can still get picked for kill objectives
/datum/game_test/room_test/station_pets_removed_on_delete/Run()
	var/mob/living/simple_animal/pet/dog/fox/renault/renault = allocate(/mob/living/simple_animal/pet/dog/fox/renault)
	var/obj/item/clothing/mask/facehugger/lamarr/lamarr = allocate(/obj/item/clothing/mask/facehugger/lamarr)
	TEST_ASSERT(renault in GLOB.station_pets, "Renault wasn't added to station pets")
	TEST_ASSERT(lamarr in GLOB.station_pets, "Lamarr wasn't added to station pets")

	qdel(renault)
	qdel(lamarr)
	TEST_ASSERT(!(renault in GLOB.station_pets), "Renault is still in station pets after being deleted")
	TEST_ASSERT(!(lamarr in GLOB.station_pets), "Lamarr is still in station pets after being deleted")
