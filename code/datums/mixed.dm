/datum/data
	var/name = "data"
	var/size = 1.0


/datum/data/function
	name = "function"
	size = 2.0


/datum/data/function/data_control
	name = "data control"


/datum/data/function/id_changer
	name = "id changer"


/datum/data/record
	name = "record"
	size = 5.0
	var/list/fields = list()

/datum/data/record/Destroy()
	if(src in GLOB.data_core.medical)
		GLOB.data_core.medical -= src
	if(src in GLOB.data_core.security)
		GLOB.data_core.security -= src
	if(src in GLOB.data_core.general)
		GLOB.data_core.general -= src
	if(src in GLOB.data_core.locked)
		GLOB.data_core.locked -= src
	return ..()

/// Makes the front and side of the record's photo for the consoles that show them. Turning a photo into text is slow
/// and most records are never opened, so it is done the first time one is. Call it before reading those fields.
/datum/data/record/proc/make_photo_text()
	if(fields["photo-south"] || !("photo" in fields))
		return
	fields["photo-south"] = "data:image/png;base64,[icon2base64(icon(fields["photo"], dir = SOUTH))]"
	fields["photo-west"] = "data:image/png;base64,[icon2base64(icon(fields["photo"], dir = WEST))]"

/datum/data/text
	name = "text"
	var/data = null

/datum/debug
	var/list/debuglist
