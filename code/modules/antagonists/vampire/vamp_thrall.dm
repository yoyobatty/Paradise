RESTRICT_TYPE(/datum/antagonist/mindslave/thrall)

/datum/antagonist/mindslave/thrall
	name = "Vampire Thrall"
	antag_hud_type = ANTAG_HUD_VAMPIRE
	antag_hud_name = "vampthrall"
	master_hud_name = "vampire"

/datum/antagonist/mindslave/thrall/add_owner_to_gamemode()
	SSticker.mode.vampire_enthralled += owner

/datum/antagonist/mindslave/thrall/remove_owner_from_gamemode()
	owner.current.create_log(CONVERSION_LOG, "Deconverted from thrall")
	SSticker.mode.vampire_enthralled -= owner

/datum/antagonist/mindslave/thrall/apply_innate_effects(mob/living/mob_override)
	. = ..()
	owner.AddSpell(new /datum/spell/vampire/thrall_commune)

/datum/antagonist/mindslave/thrall/remove_innate_effects(mob/living/mob_override)
	. = ..()
	// The old body has already lost its mind during a body change, so this has to use owner.
	owner.RemoveSpell(/datum/spell/vampire/thrall_commune)
