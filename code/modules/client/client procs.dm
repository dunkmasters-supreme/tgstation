	////////////
	//SECURITY//
	////////////
#define UPLOAD_LIMIT		10485760	//Restricts client uploads to the server to 10MB
#define MIN_CLIENT_VERSION	0		//Just an ambiguously low version for now, I don't want to suddenly stop people playing.
									//I would just like the code ready should it ever need to be used.
	/*
	When somebody clicks a link in game, this Topic is called first.
	It does the stuff in this proc and  then is redirected to the Topic() proc for the src=[0xWhatever]
	(if specified in the link). ie locate(hsrc).Topic()

	Such links can be spoofed.

	Because of this certain things MUST be considered whenever adding a Topic() for something:
		- Can it be fed harmful values which could cause runtimes?
		- Is the Topic call an admin-only thing?
		- If so, does it have checks to see if the person who called it (usr.client) is an admin?
		- Are the processes being called by Topic() particularly laggy?
		- If so, is there any protection against somebody spam-clicking a link?
	If you have any  questions about this stuff feel free to ask. ~Carn
	*/
/client/Topic(href, href_list, hsrc)
	if(!usr || usr != mob)	//stops us calling Topic for somebody else's client. Also helps prevent usr=null
		return

	//Admin PM
	if(href_list["priv_msg"])
		if (href_list["ahelp_reply"])
			cmd_ahelp_reply(href_list["priv_msg"])
			return
		cmd_admin_pm(href_list["priv_msg"],null)


		return

	//Logs all hrefs
	if(config && config.log_hrefs && href_logfile)
		href_logfile << "<small>[time2text(world.timeofday,"hh:mm")] [src] (usr:[usr])</small> || [hsrc ? "[hsrc] " : ""][href]<br>"

	switch(href_list["_src_"])
		if("holder")	hsrc = holder
		if("usr")		hsrc = mob
		if("prefs")		return prefs.process_link(usr,href_list)
		if("vars")		return view_var_Topic(href,href_list,hsrc)

	..()	//redirect to hsrc.Topic()

/client/proc/is_content_unlocked()
	if(!prefs.unlock_content)
		src << "Become a BYOND member to access member-perks and features, as well as support the engine that makes this game possible. <a href='http://www.byond.com/membership'>Click Here to find out more</a>."
		return 0
	return 1

/client/proc/handle_spam_prevention(var/message, var/mute_type)
	if(config.automute_on && !holder && src.last_message == message)
		src.last_message_count++
		if(src.last_message_count >= SPAM_TRIGGER_AUTOMUTE)
			src << "<span class='danger'>You have exceeded the spam filter limit for identical messages. An auto-mute was applied.</span>"
			cmd_admin_mute(src, mute_type, 1)
			return 1
		if(src.last_message_count >= SPAM_TRIGGER_WARNING)
			src << "<span class='danger'>You are nearing the spam filter limit for identical messages.</span>"
			return 0
	else
		last_message = message
		src.last_message_count = 0
		return 0

//This stops files larger than UPLOAD_LIMIT being sent from client to server via input(), client.Import() etc.
/client/AllowUpload(filename, filelength)
	if(filelength > UPLOAD_LIMIT)
		src << "<font color='red'>Error: AllowUpload(): File Upload too large. Upload Limit: [UPLOAD_LIMIT/1024]KiB.</font>"
		return 0
/*	//Don't need this at the moment. But it's here if it's needed later.
	//Helps prevent multiple files being uploaded at once. Or right after eachother.
	var/time_to_wait = fileaccess_timer - world.time
	if(time_to_wait > 0)
		src << "<font color='red'>Error: AllowUpload(): Spam prevention. Please wait [round(time_to_wait/10)] seconds.</font>"
		return 0
	fileaccess_timer = world.time + FTPDELAY	*/
	return 1


	///////////
	//CONNECT//
	///////////
#if (PRELOAD_RSC == 0)
var/list/external_rsc_urls
var/next_external_rsc = 0
#endif


/client/New(TopicData)

	TopicData = null							//Prevent calls to client.Topic from connect

	if(connection != "seeker")					//Invalid connection type.
		return null
	if(byond_version < MIN_CLIENT_VERSION)		//Out of date client.
		return null

#if (PRELOAD_RSC == 0)
	if(external_rsc_urls && external_rsc_urls.len)
		next_external_rsc = Wrap(next_external_rsc+1, 1, external_rsc_urls.len+1)
		preload_rsc = external_rsc_urls[next_external_rsc]
#endif

	clients += src
	directory[ckey] = src

	//Admin Authorisation
	holder = admin_datums[ckey]
	if(holder)
		admins += src
		holder.owner = src

	//preferences datum - also holds some persistant data for the client (because we may as well keep these datums to a minimum)
	prefs = preferences_datums[ckey]
	if(!prefs)
		prefs = new /datum/preferences(src)
		preferences_datums[ckey] = prefs
	prefs.last_ip = address				//these are gonna be used for banning
	prefs.last_id = computer_id			//these are gonna be used for banning

	. = ..()	//calls mob.Login()

	if( (world.address == address || !address) && !host )
		host = key
		world.update_status()

	if(holder)
		add_admin_verbs()
		admin_memo_show()
		if((global.comms_key == "default_pwd" || length(global.comms_key) <= 6) && global.comms_allowed) //It's the default value or less than 6 characters long, but it somehow didn't disable comms.
			src << "<span class='danger'>The server's API key is either too short or is the default value! Consider changing it immediately!</span>"

	add_verbs_from_config()
	set_client_age_from_db()

	if (isnum(player_age) && player_age == -1) //first connection
		if (config.panic_bunker && !holder && !(ckey in deadmins))
			log_access("Failed Login: [key] - New account attempting to connect during panic bunker")
			message_admins("<span class='adminnotice'>Failed Login: [key] - New account attempting to connect during panic bunker</span>")
			src << "Sorry but the server is currently not accepting connections from never before seen players."
			del(src)
			return 0

		if (config.notify_new_player_age >= 0)
			message_admins("New user: [key_name_admin(src)] is connecting here for the first time.")
			if (config.irc_first_connection_alert)
				send2irc_adminless_only("New-user", "[key_name(src)] is connecting for the first time!")

		player_age = 0 // set it from -1 to 0 so the job selection code doesn't have a panic attack

	else if (isnum(player_age) && player_age < config.notify_new_player_age)
		message_admins("New user: [key_name_admin(src)] just connected with an age of [player_age] day[(player_age==1?"":"s")]")


	if (!ticker || ticker.current_state == GAME_STATE_PREGAME)
		spawn (rand(10,150))
			if (src)
				sync_client_with_db()
	else
		sync_client_with_db()

	send_resources()

	if(!void)
		void = new()
	screen += void

	if(prefs.lastchangelog != changelog_hash) //bolds the changelog button on the interface so we know there are updates.
		src << "<span class='info'>You have unread updates in the changelog.</span>"
		if(config.aggressive_changelog)
			src.changes()
		else
			winset(src, "rpane.changelogb", "background-color=#eaeaea;font-style=bold")

	if (ckey in clientmessages)
		for (var/message in clientmessages[ckey])
			src << message
		clientmessages.Remove(ckey)
		
	holder = admin_datums[ckey]
	if(holder)
		player_anonyname = "Admin ([rand(1, 1000)])"
	else
		player_anonyname = "Player ([rand(1, 1000)])"

	//////////////
	//DISCONNECT//
	//////////////
/client/Del()
	if(holder)
		holder.owner = null
		admins -= src
	directory -= ckey
	clients -= src
	return ..()


/client/proc/set_client_age_from_db()
	if (IsGuestKey(src.key))
		return

	establish_db_connection()
	if(!dbcon.IsConnected())
		return

	var/sql_ckey = sanitizeSQL(src.ckey)

	var/DBQuery/query = dbcon.NewQuery("SELECT id, datediff(Now(),firstseen) as age FROM [format_table_name("player")] WHERE ckey = '[sql_ckey]'")
	if (!query.Execute())
		return

	while (query.NextRow())
		player_age = text2num(query.item[2])
		return

	//no match mark it as a first connection for use in client/New()
	player_age = -1


/client/proc/sync_client_with_db()
	if (IsGuestKey(src.key))
		return

	establish_db_connection()
	if (!dbcon.IsConnected())
		return

	var/sql_ckey = sanitizeSQL(src.ckey)

	var/DBQuery/query_ip = dbcon.NewQuery("SELECT ckey FROM [format_table_name("player")] WHERE ip = '[address]' AND ckey != '[sql_ckey]'")
	query_ip.Execute()
	related_accounts_ip = ""
	while(query_ip.NextRow())
		related_accounts_ip += "[query_ip.item[1]], "

	var/DBQuery/query_cid = dbcon.NewQuery("SELECT ckey FROM [format_table_name("player")] WHERE computerid = '[computer_id]' AND ckey != '[sql_ckey]'")
	query_cid.Execute()
	related_accounts_cid = ""
	while (query_cid.NextRow())
		related_accounts_cid += "[query_cid.item[1]], "

	var/DBQuery/query_watch = dbcon.NewQuery("SELECT ckey, reason FROM [format_table_name("watch")] WHERE (ckey = '[sql_ckey]')")
	query_watch.Execute()
	if(query_watch.NextRow())
		message_admins("<font color='red'><B>Notice: </B></font><font color='blue'>[key_name_admin(src)] is flagged for watching and has just connected - Reason: [query_watch.item[2]]</font>")
		send2irc_adminless_only("Watchlist", "[key_name(src)] is flagged for watching and has just connected - Reason: [query_watch.item[2]]")


	var/admin_rank = "Player"
	if (src.holder && src.holder.rank)
		admin_rank = src.holder.rank.name
	else
		if (check_randomizer())
			return

	var/sql_ip = sanitizeSQL(src.address)
	var/sql_computerid = sanitizeSQL(src.computer_id)
	var/sql_admin_rank = sanitizeSQL(admin_rank)


	var/DBQuery/query_insert = dbcon.NewQuery("INSERT INTO [format_table_name("player")] (id, ckey, firstseen, lastseen, ip, computerid, lastadminrank) VALUES (null, '[sql_ckey]', Now(), Now(), '[sql_ip]', '[sql_computerid]', '[sql_admin_rank]') ON DUPLICATE KEY UPDATE lastseen = VALUES(lastseen), ip = VALUES(ip), computerid = VALUES(computerid), lastadminrank = VALUES(lastadminrank)")
	query_insert.Execute()

	//Logging player access
	var/serverip = "[world.internet_address]:[world.port]"
	var/DBQuery/query_accesslog = dbcon.NewQuery("INSERT INTO `[format_table_name("connection_log")]` (`id`,`datetime`,`serverip`,`ckey`,`ip`,`computerid`) VALUES(null,Now(),'[serverip]','[sql_ckey]','[sql_ip]','[sql_computerid]');")
	query_accesslog.Execute()

/client/proc/add_verbs_from_config()
	if(config.see_own_notes)
		verbs += /client/proc/self_notes



/client/proc/check_randomizer()
	. = FALSE
	if (!config.check_randomizer)
		return
	var/static/cidcheck = list()
	var/static/cidcheck_failedckeys = list() //to avoid spamming the admins if the same guy keeps trying.

	var/oldcid = cidcheck[ckey]
	if (oldcid)
		if (oldcid != computer_id) //IT CHANGED!!!
			cidcheck -= ckey //so they can try again after removing the cid randomizer.

			src << "<span class='userdanger'>Connection Error:</span>"
			src << "<span class='danger'>Invalid ComputerID(spoofed). Please remove the ComputerID spoofer from your byond installation and try again.</span>"

			if (!cidcheck_failedckeys[ckey])
				message_admins("<span class='adminnotice'>[key_name(src)] has been detected as using a cid randomizer. Connection rejected.</span>")
				send2irc_adminless_only("CidRandomizer", "[key_name(src)] has been detected as using a cid randomizer. Connection rejected.")
				cidcheck_failedckeys[ckey] = 1
				note_randomizer_user()

			log_access("Failed Login: [key] [computer_id] [address] - CID randomizer confirmed (oldcid: [oldcid])")

			del(src)
			return TRUE
		else
			if (cidcheck_failedckeys[ckey])
				message_admins("<span class='adminnotice'>[key_name_admin(src)] has been allowed to connect after showing they removed their cid randomizer</span>")
				send2irc_adminless_only("CidRandomizer", "[key_name(src)] has been allowed to connect after showing they removed their cid randomizer.")
				cidcheck_failedckeys -= ckey
			cidcheck -= ckey
	else
		var/sql_ckey = sanitizeSQL(ckey)
		var/DBQuery/query_cidcheck = dbcon.NewQuery("SELECT computerid FROM [format_table_name("player")] WHERE ckey = '[sql_ckey]'")
		query_cidcheck.Execute()

		var/lastcid
		if (query_cidcheck.NextRow())
			lastcid = query_cidcheck.item[1]

		if (computer_id != lastcid)
			cidcheck[ckey] = computer_id
			log_access("Failed Login: [key] [computer_id] [address] - CID randomizer check")

			var/url = winget(src, null, "url")
			//special javascript to make them reconnect under a new window.
			src << browse("<a id='link' href=byond://[url]>byond://[url]</a><script type='text/javascript'>document.getElementById(\"link\").click();window.location=\"byond://winset?command=.quit\"</script>", "border=0;titlebar=0;size=1x1")
			winset(src, "reconnectbutton", "is-disable=true") //reconnect keeps the same cid in the randomizer, they could use this button to fake it.
			sleep(10) //browse is queued, we don't want them to disconnect before getting the browse() command.

			//teeheehee (in case the above method doesn't work, its not 100% reliable.)
			src << "<pre class=\"system system\">Network connection shutting down due to read error.</pre>"
			del(src)
			return TRUE

/client/proc/note_randomizer_user()
	var/const/adminckey = "CID-Error"
	var/sql_ckey = sanitizeSQL(ckey)
	//check to see if we noted them in the last day.
	var/DBQuery/query_get_notes = dbcon.NewQuery("SELECT id FROM [format_table_name("notes")] WHERE ckey = '[sql_ckey]' AND adminckey = '[adminckey]' AND timestamp + INTERVAL 1 DAY < NOW()")
	if(!query_get_notes.Execute())
		var/err = query_get_notes.ErrorMsg()
		log_game("SQL ERROR obtaining id from notes table. Error : \[[err]\]\n")
		return
	if (query_get_notes.NextRow())
		return

	//regardless of above, make sure their last note is not from us, as no point in repeating the same note over and over.
	query_get_notes = dbcon.NewQuery("SELECT adminckey FROM [format_table_name("notes")] WHERE ckey = '[sql_ckey]' ORDER BY timestamp DESC LIMIT 1")
	if(!query_get_notes.Execute())
		var/err = query_get_notes.ErrorMsg()
		log_game("SQL ERROR obtaining id from notes table. Error : \[[err]\]\n")
		return
	if (query_get_notes.NextRow())
		if (query_get_notes.item[1] == adminckey)
			return
	add_note(ckey, "Detected as using a cid randomizer.", null, adminckey, logged = 0)

#undef TOPIC_SPAM_DELAY
#undef UPLOAD_LIMIT
#undef MIN_CLIENT_VERSION

//checks if a client is afk
//3000 frames = 5 minutes
/client/proc/is_afk(duration=3000)
	if(inactivity > duration)	return inactivity
	return 0

//send resources to the client. It's here in its own proc so we can move it around easiliy if need be
/client/proc/send_resources()

	spawn
		// Preload the HTML interface. This needs to be done due to BYOND bug http://www.byond.com/forum/?post=1487244
		var/datum/html_interface/hi
		for (var/type in typesof(/datum/html_interface))
			hi = new type(null)
			hi.sendResources(src)

	// Preload the crew monitor. This needs to be done due to BYOND bug http://www.byond.com/forum/?post=1487244
	spawn
		if (crewmonitor && crewmonitor.initialized)
			crewmonitor.sendResources(src)

	//Send nanoui files to client
	SSnano.send_resources(src)
	getFiles(
		'html/search.js',
		'html/panels.css',
		'html/browser/common.css',
		'html/browser/scannernew.css',
		'html/browser/playeroptions.css',
		'icons/pda_icons/pda_atmos.png',
		'icons/pda_icons/pda_back.png',
		'icons/pda_icons/pda_bell.png',
		'icons/pda_icons/pda_blank.png',
		'icons/pda_icons/pda_boom.png',
		'icons/pda_icons/pda_bucket.png',
		'icons/pda_icons/pda_chatroom.png',
		'icons/pda_icons/pda_medbot.png',
		'icons/pda_icons/pda_floorbot.png',
		'icons/pda_icons/pda_cleanbot.png',
		'icons/pda_icons/pda_crate.png',
		'icons/pda_icons/pda_cuffs.png',
		'icons/pda_icons/pda_eject.png',
		'icons/pda_icons/pda_exit.png',
		'icons/pda_icons/pda_flashlight.png',
		'icons/pda_icons/pda_honk.png',
		'icons/pda_icons/pda_mail.png',
		'icons/pda_icons/pda_medical.png',
		'icons/pda_icons/pda_menu.png',
		'icons/pda_icons/pda_mule.png',
		'icons/pda_icons/pda_notes.png',
		'icons/pda_icons/pda_power.png',
		'icons/pda_icons/pda_rdoor.png',
		'icons/pda_icons/pda_reagent.png',
		'icons/pda_icons/pda_refresh.png',
		'icons/pda_icons/pda_scanner.png',
		'icons/pda_icons/pda_signaler.png',
		'icons/pda_icons/pda_status.png',
		'icons/spideros_icons/sos_1.png',
		'icons/spideros_icons/sos_2.png',
		'icons/spideros_icons/sos_3.png',
		'icons/spideros_icons/sos_4.png',
		'icons/spideros_icons/sos_5.png',
		'icons/spideros_icons/sos_6.png',
		'icons/spideros_icons/sos_7.png',
		'icons/spideros_icons/sos_8.png',
		'icons/spideros_icons/sos_9.png',
		'icons/spideros_icons/sos_10.png',
		'icons/spideros_icons/sos_11.png',
		'icons/spideros_icons/sos_12.png',
		'icons/spideros_icons/sos_13.png',
		'icons/spideros_icons/sos_14.png',
		'icons/stamp_icons/large_stamp-clown.png',
		'icons/stamp_icons/large_stamp-deny.png',
		'icons/stamp_icons/large_stamp-ok.png',
		'icons/stamp_icons/large_stamp-hop.png',
		'icons/stamp_icons/large_stamp-cmo.png',
		'icons/stamp_icons/large_stamp-ce.png',
		'icons/stamp_icons/large_stamp-hos.png',
		'icons/stamp_icons/large_stamp-rd.png',
		'icons/stamp_icons/large_stamp-cap.png',
		'icons/stamp_icons/large_stamp-qm.png',
		'icons/stamp_icons/large_stamp-law.png'
		)
