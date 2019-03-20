var/bomb_set

/obj/machinery/nuclearbomb
	name = "nuclear fission explosive"
	desc = "You probably shouldn't stick around to see if this is armed."
	icon = 'icons/obj/stationobjs.dmi'
	icon_state = "nuclearbomb0"
	density = 1

	var/timeleft = 60.0
	var/timing = 0.0
	var/unlock_code = "ADMIN"
	var/input_code = ""
	var/unlocked = 0
	var/safety = 1.0
	var/obj/item/weapon/disk/nuclear/auth = null
	use_power = 0
	var/previous_level = ""
	var/lastentered = ""
	var/immobile = 0 //Not all nukes should be moved

/obj/machinery/nuclearbomb/selfdestruct
	name = "station self-destruct terminal"
	desc = "For when it all gets too much to bear. Do not taunt."
	icon = 'icons/obj/machines/bignuke.dmi'
	anchored = 1 //stops it being moved
	immobile = 1 //prevents it from ever being moved
	layer = 4

/obj/machinery/nuclearbomb/process()
	if (timing)
		bomb_set = 1 //So long as there is one nuke timing, it means one nuke is armed.
		timeleft--
		if (timeleft <= 0)
			explode()
		else
			var/volume = (timeleft <= 20 ? 30 : 5)
			playsound(loc, 'sound/items/timer.ogg', volume, 0)
		for(var/mob/M in viewers(1, src))
			if ((M.client && M.machine == src))
				attack_hand(M)
	return

/obj/machinery/nuclearbomb/attackby(obj/item/weapon/I as obj, mob/user as mob, params)
	if (istype(I, /obj/item/weapon/disk/nuclear))
		usr.drop_item()
		I.loc = src
		auth = I
		add_fingerprint(user)
		return
	..()

/obj/machinery/nuclearbomb/attack_paw(mob/user as mob)
	return attack_hand(user)

/obj/machinery/nuclearbomb/attack_ai(mob/user as mob)
	return

/obj/machinery/nuclearbomb/attack_hand(mob/user as mob)
	user.set_machine(src)
	var/dat = text("<TT>\nAuth. Disk: <A href='?src=\ref[];auth=1'>[]</A><HR>", src, (auth ? "++++++++++" : "----------"))
	if (auth)
		if (unlocked)
			dat += text("\n<B>Status</B>: []-[]<BR>\n<B>Timer</B>: []<BR>\n<BR>\nTimer: [] <A href='?src=\ref[];timer=1'>Toggle</A><BR>\nTime: <A href='?src=\ref[];time=-10'>-</A> <A href='?src=\ref[];time=-1'>-</A> [] <A href='?src=\ref[];time=1'>+</A> <A href='?src=\ref[];time=10'>+</A><BR>\n<BR>\nSafety: [] <A href='?src=\ref[];safety=1'>Toggle</A><BR>\nAnchor: [] <A href='?src=\ref[];anchor=1'>Toggle</A><BR>\n", (timing ? "Func/Set" : "Functional"), (safety ? "Safe" : "Engaged"), timeleft, (timing ? "On" : "Off"), src, src, src, timeleft, src, src, (safety ? "On" : "Off"), src, (anchored ? "Engaged" : "Off"), src)
		else
			dat += text("\n<B>Status</B>: Auth. S2-[]<BR>\n<B>Timer</B>: []<BR>\n<BR>\nTimer: [] Toggle<BR>\nTime: - - [] + +<BR>\n<BR>\n[] Safety: Toggle<BR>\nAnchor: [] Toggle<BR>\n", (safety ? "Safe" : "Engaged"), timeleft, (timing ? "On" : "Off"), timeleft, (safety ? "On" : "Off"), (anchored ? "Engaged" : "Off"))
	else
		if (timing)
			dat += text("\n<B>Status</B>: Set-[]<BR>\n<B>Timer</B>: []<BR>\n<BR>\nTimer: [] Toggle<BR>\nTime: - - [] + +<BR>\n<BR>\nSafety: [] Toggle<BR>\nAnchor: [] Toggle<BR>\n", (safety ? "Safe" : "Engaged"), timeleft, (timing ? "On" : "Off"), timeleft, (safety ? "On" : "Off"), (anchored ? "Engaged" : "Off"))
		else
			dat += text("\n<B>Status</B>: Auth. S1-[]<BR>\n<B>Timer</B>: []<BR>\n<BR>\nTimer: [] Toggle<BR>\nTime: - - [] + +<BR>\n<BR>\nSafety: [] Toggle<BR>\nAnchor: [] Toggle<BR>\n", (safety ? "Safe" : "Engaged"), timeleft, (timing ? "On" : "Off"), timeleft, (safety ? "On" : "Off"), (anchored ? "Engaged" : "Off"))
	var/message = "AUTH"
	if (auth)
		message = text("[]", input_code)
		if (unlocked)
			message = "*****"
	dat += text("<HR>\n>[]<BR>\n<A href='?src=\ref[];type=1'>1</A><A href='?src=\ref[];type=2'>2</A><A href='?src=\ref[];type=3'>3</A><BR>\n<A href='?src=\ref[];type=4'>4</A><A href='?src=\ref[];type=5'>5</A><A href='?src=\ref[];type=6'>6</A><BR>\n<A href='?src=\ref[];type=7'>7</A><A href='?src=\ref[];type=8'>8</A><A href='?src=\ref[];type=9'>9</A><BR>\n<A href='?src=\ref[];type=R'>R</A><A href='?src=\ref[];type=0'>0</A><A href='?src=\ref[];type=E'>E</A><BR>\n</TT>", message, src, src, src, src, src, src, src, src, src, src, src, src)
	var/datum/browser/popup = new(user, "nuclearbomb", name, 300, 400)
	popup.set_content(dat)
	popup.open()
	return

/obj/machinery/nuclearbomb/Topic(href, href_list)
	if(..())
		return
	usr.set_machine(src)
	if (href_list["auth"])
		if (auth)
			auth.loc = loc
			unlocked = 0
			auth = null
		else
			var/obj/item/I = usr.get_active_hand()
			if (istype(I, /obj/item/weapon/disk/nuclear))
				usr.drop_item()
				I.loc = src
				auth = I
	if (auth)
		if (href_list["type"])
			if (href_list["type"] == "E")
				if (input_code == unlock_code)
					unlocked = 1
					input_code = null
				else
					input_code = "ERROR"
			else
				if (href_list["type"] == "R")
					unlocked = 0
					input_code = null
				else
					lastentered = text("[]", href_list["type"])
					if (text2num(lastentered) == null)
						var/turf/LOC = get_turf(usr)
						message_admins("[key_name_admin(usr)] (<A HREF='?_src_=holder;adminplayerobservefollow=\ref[usr]'>FLW</A>) tried to exploit a nuclear bomb by entering non-numerical codes: <a href='?_src_=vars;Vars=\ref[src]'>[lastentered]</a> ! ([LOC ? "<a href='?_src_=holder;adminplayerobservecoodjump=1;X=[LOC.x];Y=[LOC.y];Z=[LOC.z]'>JMP</a>" : "null"])", 0)
						log_admin("EXPLOIT : [key_name(usr)] tried to exploit a nuclear bomb by entering non-numerical codes: [lastentered] !")
					else
						input_code += lastentered
						if (length(input_code) > 5)
							input_code = "ERROR"
		if (unlocked)
			if (href_list["time"])
				var/time = text2num(href_list["time"])
				timeleft += time
				timeleft = min(max(round(timeleft), 60), 600)
			if (href_list["timer"])
				if (timing == -1.0)
					return
				if (safety)
					usr << "<span class='danger'>The safety is still on.</span>"
					return
				timing = !( timing )
				if (timing)
					icon_state = "nuclearbomb2"
					if(!safety)
						bomb_set = 1//There can still be issues with this reseting when there are multiple bombs. Not a big deal tho for Nuke/N
						var/current_level = get_security_level()
						previous_level = "[current_level == "delta" ? "red" : current_level ]" //If a nuke is armed during Delta, it will stand down to Red Alert when disarmed.
						set_security_level("delta")
					else
						bomb_set = 0
						set_security_level("[previous_level]")
				else
					icon_state = "nuclearbomb1"
					bomb_set = 0
					set_security_level("[previous_level]")
			if (href_list["safety"])
				safety = !( safety )
				icon_state = "nuclearbomb1"
				if(safety)
					timing = 0
					bomb_set = 0
					set_security_level("[previous_level]")
			if (href_list["anchor"])
				if(!isinspace()&&(!immobile))
					anchored = !( anchored )
				else if(immobile)
					usr << "<span class='warning'>This device is immovable!</span>"
				else
					usr << "<span class='warning'>There is nothing to anchor to!</span>"
	add_fingerprint(usr)
	for(var/mob/M in viewers(1, src))
		if ((M.client && M.machine == src))
			attack_hand(M)


/obj/machinery/nuclearbomb/ex_act(severity, target)
	return

/obj/machinery/nuclearbomb/blob_act()
	if (timing == -1.0)
		return
	else
		return ..()
	return


#define NUKERANGE 80
/obj/machinery/nuclearbomb/proc/explode()
	if (safety)
		timing = 0
		return
	timing = -1.0
	unlocked = 0
	safety = 1
	icon_state = "nuclearbomb3"
	for(var/mob/M in player_list)
		M << 'sound/machines/Alarm.ogg'
	if (ticker && ticker.mode)
		ticker.mode.explosion_in_progress = 1
	sleep(100)

	enter_allowed = 0

	var/off_station = 0
	var/turf/bomb_location = get_turf(src)
	if( bomb_location && (bomb_location.z == ZLEVEL_STATION) )
		if( (bomb_location.x < (128-NUKERANGE)) || (bomb_location.x > (128+NUKERANGE)) || (bomb_location.y < (128-NUKERANGE)) || (bomb_location.y > (128+NUKERANGE)) )
			off_station = 1
	else
		off_station = 2

	if(ticker.mode && ticker.mode.name == "nuclear emergency")
		var/obj/docking_port/mobile/Shuttle = SSshuttle.getShuttle("syndicate")
		ticker.mode:syndies_didnt_escape = (Shuttle && Shuttle.z == ZLEVEL_CENTCOM) ? 0 : 1
		ticker.mode:nuke_off_station = off_station
	ticker.station_explosion_cinematic(off_station,null)
	if(ticker.mode)
		ticker.mode.explosion_in_progress = 0
		if(ticker.mode.name == "nuclear emergency")
			ticker.mode:nukes_left --
		else
			world << "<B>The station was destoyed by the nuclear blast!</B>"

		ticker.mode.station_was_nuked = (off_station<2)	//offstation==1 is a draw. the station becomes irradiated and needs to be evacuated.
														//kinda shit but I couldn't  get permission to do what I wanted to do.

		if(!ticker.mode.check_finished())//If the mode does not deal with the nuke going off so just reboot because everyone is stuck as is
			world.Reboot("Station destroyed by Nuclear Device.", "end_error", "nuke - unhandled ending")
	return

/*
This is here to make the tiles around the station mininuke change when it's armed.
*/

/obj/machinery/nuclearbomb/selfdestruct/proc/SetTurfs()
	if(loc == initial(loc))
		var/text_icon_state = "[timing ? "rcircuitanim" : "gcircuit"]"
		for(var/turf/simulated/floor/bluegrid/T in orange(src, 1))
			T.icon_state = text_icon_state

/obj/machinery/nuclearbomb/selfdestruct/Topic()
        ..()
        SetTurfs()



//==========DAT FUKKEN DISK===============
/obj/item/weapon/disk
	icon = 'icons/obj/module.dmi'
	w_class = 1
	item_state = "card-id"
	icon_state = "datadisk0"

/obj/item/weapon/disk/nuclear
	name = "nuclear authentication disk"
	desc = "Better keep this safe."
	icon_state = "nucleardisk"

/obj/item/weapon/disk/nuclear/New()
	..()
	SSobj.processing |= src

/obj/item/weapon/disk/nuclear/process()
	var/turf/disk_loc = get_turf(src)
	if(disk_loc.z > ZLEVEL_CENTCOM)
		get(src, /mob) << "<span class='danger'>You can't help but feel that you just lost something back there...</span>"
		qdel(src)

/obj/item/weapon/disk/nuclear/Destroy()
	if(blobstart.len > 0)
		var/obj/item/weapon/disk/nuclear/NEWDISK = new(pick(blobstart))
		transfer_fingerprints_to(NEWDISK)
		var/turf/diskturf = get_turf(src)
		message_admins("[src] has been destroyed in ([diskturf.x], [diskturf.y] ,[diskturf.z] - <A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[diskturf.x];Y=[diskturf.y];Z=[diskturf.z]'>JMP</a>). Moving it to ([NEWDISK.x], [NEWDISK.y], [NEWDISK.z] - <A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[NEWDISK.x];Y=[NEWDISK.y];Z=[NEWDISK.z]'>JMP</a>).")
		log_game("[src] has been destroyed in ([diskturf.x], [diskturf.y] ,[diskturf.z]). Moving it to ([NEWDISK.x], [NEWDISK.y], [NEWDISK.z]).")
		return QDEL_HINT_HARDDEL_NOW //Needed to clear all references to it
	else
		ERROR("[src] was supposed to be destroyed, but we were unable to locate a blobstart landmark to spawn a new one.")
	return QDEL_HINT_LETMELIVE // Cancel destruction.
