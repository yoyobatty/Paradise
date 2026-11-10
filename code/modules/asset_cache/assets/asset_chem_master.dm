/// Pill sprites for UIs
/datum/asset/spritesheet/chem_master
	name = "chem_master"

/datum/asset/spritesheet/chem_master/create_spritesheets()
	// Zoomed in on the middle
	var/list/transforms = list(ICONFORGE_SCALE(64, 64), ICONFORGE_CROP(16, 16, 48, 48), ICONFORGE_SCALE(32, 32))
	for(var/pill_type in 1 to 28)
		Insert("pill[pill_type]", 'icons/obj/chemical.dmi', "pill[pill_type]", transforms = transforms)
	for(var/bandaid_type in 1 to 21)
		Insert("bandaid[bandaid_type]", 'icons/obj/chemical.dmi', "bandaid[bandaid_type]", transforms = transforms)
	for(var/bottle_type in list("bottle", "reagent_bottle"))
		Insert(bottle_type, 'icons/obj/chemical.dmi', bottle_type, transforms = transforms)
