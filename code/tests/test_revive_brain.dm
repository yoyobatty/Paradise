/// A body revived with nobody in it has to take its owner's mind back out of their removed brain
/datum/game_test/room_test/revive_takes_mind_from_brain/Run()
	var/datum/test_puppeteer/player = new(src)
	var/mob/living/carbon/human/original = player.puppet
	var/datum/mind/mind = original.mind
	var/obj/item/organ/internal/brain/brain = original.get_int_organ(/obj/item/organ/internal/brain)
	brain.remove(original)
	TEST_ASSERT(brain.brainmob?.mind == mind, "Removing the brain didn't take the mind with it")

	var/mob/living/carbon/human/body = allocate(/mob/living/carbon/human)
	body.real_name = brain.brainmob.real_name
	body.revive()
	TEST_ASSERT(body.mind == mind, "revive() didn't give the body its owner's mind back")
	TEST_ASSERT(QDELETED(brain), "revive() left the brain it took the mind from")
