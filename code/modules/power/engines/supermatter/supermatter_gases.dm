/// The gases the supermatter cares about, in the order it adds them up. Agent B isn't here, it only thins out the others.
GLOBAL_LIST_INIT(supermatter_gases, list(
	new /datum/sm_gas/plasma,
	new /datum/sm_gas/oxygen,
	new /datum/sm_gas/carbon_dioxide,
	new /datum/sm_gas/nitrogen,
	new /datum/sm_gas/nitrous_oxide,
	new /datum/sm_gas/hydrogen,
	new /datum/sm_gas/water_vapor,
))

/**
 * How one gas affects the supermatter.
 *
 * Every cycle the crystal works out what share of its gas each of these is,
 * and adds up these numbers weighted by that share.
 */
/datum/sm_gas
	/// The key for this gas in the crystal's gas_comp list
	var/id
	/// 1 if the crystal makes power from this gas being hot, -1 if this gas holds that back, 0 if neither
	var/power_ratio = 0
	/// Higher means more heat, plasma and oxygen given off. Negative numbers lower it
	var/heat_penalty = 0
	/// Higher means more radiation, which is more power for the collectors
	var/transmit_modifier = 0
	/// Higher means the crystal can take more heat before it gets damaged
	var/heat_resistance = 0
	/// How much this gas adds to radiation and zaps once the chamber gets crowded
	var/crunch = 0

/// How many moles of this gas are in the mix
/datum/sm_gas/proc/get_moles(datum/gas_mixture/air)
	return 0

/datum/sm_gas/plasma
	id = "plasma"
	power_ratio = 1
	heat_penalty = 20
	transmit_modifier = 6
	crunch = 4

/datum/sm_gas/plasma/get_moles(datum/gas_mixture/air)
	return air.toxins()

/datum/sm_gas/oxygen
	id = "oxygen"
	power_ratio = 1
	heat_penalty = 1
	transmit_modifier = 2
	crunch = 1.5

/datum/sm_gas/oxygen/get_moles(datum/gas_mixture/air)
	return air.oxygen()

/datum/sm_gas/carbon_dioxide
	id = "carbon_dioxide"
	power_ratio = 1
	heat_penalty = 0.1
	crunch = 1

/datum/sm_gas/carbon_dioxide/get_moles(datum/gas_mixture/air)
	return air.carbon_dioxide()

/datum/sm_gas/nitrogen
	id = "nitrogen"
	power_ratio = -1
	heat_penalty = -1
	crunch = 0.55

/datum/sm_gas/nitrogen/get_moles(datum/gas_mixture/air)
	return air.nitrogen()

/datum/sm_gas/nitrous_oxide
	id = "nitrous_oxide"
	heat_resistance = 6
	crunch = 0.55

/datum/sm_gas/nitrous_oxide/get_moles(datum/gas_mixture/air)
	return air.sleeping_agent()

/datum/sm_gas/hydrogen
	id = "hydrogen"
	power_ratio = 1
	heat_penalty = 30
	transmit_modifier = 4
	crunch = 2

/datum/sm_gas/hydrogen/get_moles(datum/gas_mixture/air)
	return air.hydrogen()

/datum/sm_gas/water_vapor
	id = "water_vapor"
	power_ratio = 1
	heat_penalty = 5
	transmit_modifier = -10
	crunch = 0.75

/datum/sm_gas/water_vapor/get_moles(datum/gas_mixture/air)
	return air.water_vapor()
