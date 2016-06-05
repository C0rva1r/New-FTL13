////////////////////////
// CLOCKWORK MACHINES //
////////////////////////
//not-actually-machines

/obj/structure/clockwork/powered
	var/obj/machinery/power/apc/target_apc
	var/active = FALSE
	var/needs_power = TRUE
	var/active_icon = null //icon_state while process() is being called
	var/inactive_icon = null //icon_state while process() isn't being called

/obj/structure/clockwork/powered/examine(mob/user)
	..()
	if(is_servant_of_ratvar(user) || isobserver(user))
		var/powered = total_accessable_power()
		user << "<span class='[powered ? "brass":"alloy"]'>It has access to [powered == INFINITY ? "infinite":"[powered]"]W of power.</span>"

/obj/structure/clockwork/powered/Destroy()
	SSfastprocess.processing -= src
	SSobj.processing -= src
	return ..()

/obj/structure/clockwork/powered/process()
	var/powered = total_accessable_power()
	return powered == PROCESS_KILL ? 25 : powered //make sure we don't accidentally return the arbitrary PROCESS_KILL define

/obj/structure/clockwork/powered/proc/toggle(fast_process, mob/living/user)
	if(user)
		if(!is_servant_of_ratvar(user))
			return 0
		user.visible_message("<span class='notice'>[user] [active ? "dis" : "en"]ables [src].</span>", "<span class='brass'>You [active ? "dis" : "en"]able [src].</span>")
	active = !active
	if(active)
		icon_state = active_icon
		if(fast_process)
			SSfastprocess.processing |= src
		else
			SSobj.processing |= src
	else
		icon_state = inactive_icon
		SSfastprocess.processing -= src
		SSobj.processing -= src


/obj/structure/clockwork/powered/proc/total_accessable_power() //how much power we have and can use
	if(!needs_power || ratvar_awakens)
		return INFINITY //oh yeah we've got power why'd you ask

	var/power = 0
	power += accessable_apc_power()
	power += accessable_sigil_power()
	return power

/obj/structure/clockwork/powered/proc/accessable_apc_power()
	var/power = 0
	var/area/A = get_area(src)
	var/area/targetAPCA
	for(var/obj/machinery/power/apc/APC in apcs_list)
		var/area/APCA = get_area(APC)
		if(APCA == A)
			target_apc = APC
	if(target_apc)
		targetAPCA = get_area(target_apc)
		if(targetAPCA != A)
			target_apc = null
		else if(target_apc.cell)
			var/apccharge = target_apc.cell.charge
			if(apccharge >= 50)
				power += apccharge
	return power

/obj/structure/clockwork/powered/proc/accessable_sigil_power()
	var/power = 0
	for(var/obj/effect/clockwork/sigil/transmission/T in range(1, src))
		power += T.power_charge
	return power


/obj/structure/clockwork/powered/proc/try_use_power(amount) //try to use an amount of power
	if(!needs_power)
		return 1
	if(amount <= 0)
		return 0
	var/power = total_accessable_power()
	if(!power || power < amount)
		return 0
	return use_power(amount)

/obj/structure/clockwork/powered/proc/use_power(amount) //we've made sure we had power, so now we use it
	var/sigilpower = accessable_sigil_power()
	var/list/sigils_in_range = list()
	for(var/obj/effect/clockwork/sigil/transmission/T in range(1, src))
		sigils_in_range |= T
	while(sigilpower && amount >= 50)
		for(var/S in sigils_in_range)
			var/obj/effect/clockwork/sigil/transmission/T = S
			if(T.modify_charge(50))
				sigilpower -= 50
				amount -= 50
	var/apcpower = accessable_apc_power()
	while(apcpower >= 50 && amount >= 50)
		if(target_apc.cell.use(50))
			apcpower -= 50
			amount -= 50
		else
			apcpower = 0
	if(amount)
		return 0
	else
		return 1



/obj/structure/clockwork/powered/mending_motor //Mending motor: A prism that consumes replicant alloy to repair nearby mechanical servants at a quick rate.
	name = "mending motor"
	desc = "A dark onyx prism, held in midair by spiraling tendrils of stone."
	clockwork_desc = "A powerful prism that rapidly repairs nearby mechanical servants and clockwork structures."
	icon_state = "mending_motor_inactive"
	active_icon = "mending_motor"
	inactive_icon = "mending_motor_inactive"
	construction_value = 20
	break_message = "<span class='warning'>The prism collapses with a heavy thud!</span>"
	var/stored_alloy = 0 //250W = 1 alloy
	var/max_alloy = 50000

/obj/structure/clockwork/powered/mending_motor/prefilled
	stored_alloy = 5000 //starts with 20 alloy

/obj/structure/clockwork/powered/mending_motor/total_accessable_power()
	. = ..()
	if(. != INFINITY)
		. += accessable_alloy_power()

/obj/structure/clockwork/powered/mending_motor/proc/accessable_alloy_power()
	return stored_alloy

/obj/structure/clockwork/powered/mending_motor/use_power(amount)
	var/alloypower = accessable_alloy_power()
	while(alloypower >= 50 && amount >= 50)
		stored_alloy -= 50
		alloypower -= 50
		amount -= 50
	return ..()

/obj/structure/clockwork/powered/mending_motor/examine(mob/user)
	..()
	if(is_servant_of_ratvar(user) || isobserver(user))
		user << "<span class='alloy'>It has [stored_alloy*0.004]/[max_alloy*0.004] units of replicant alloy, which is equivalent to [stored_alloy]W/[max_alloy]W of power.</span>"

/obj/structure/clockwork/powered/mending_motor/process()
	if(!..())
		visible_message("<span class='warning'>[src] emits an airy chuckling sound and falls dark!</span>")
		toggle()
		return
	for(var/atom/movable/M in range(5, src))
		if(istype(M, /mob/living/simple_animal/hostile/clockwork_marauder))
			var/mob/living/simple_animal/hostile/clockwork_marauder/E = M
			if((E.health == E.maxHealth && !E.fatigue) || E.stat)
				continue
			if(!try_use_power(150))
				break
			E.adjustBruteLoss(-E.maxHealth) //Instant because marauders don't usually take health damage
			E.fatigue = max(0, E.fatigue - 15)
		else if(istype(M, /mob/living/simple_animal/hostile/anima_fragment))
			var/mob/living/simple_animal/hostile/anima_fragment/F = M
			if(F.health == F.maxHealth || F.stat)
				continue
			if(!try_use_power(200))
				break
			F.adjustBruteLoss(-15)
		else if(istype(M, /obj/structure/clockwork))
			var/obj/structure/clockwork/C = M
			if(C.health == C.max_health)
				continue
			if(!try_use_power(250))
				break
			C.health = min(C.health + 15, C.max_health)
		else if(issilicon(M))
			var/mob/living/silicon/S = M
			if(S.health == S.maxHealth || S.stat == DEAD || !is_servant_of_ratvar(S))
				continue
			if(!try_use_power(300))
				break
			S.adjustBruteLoss(-15)
			S.adjustFireLoss(-15)
	return 1

/obj/structure/clockwork/powered/mending_motor/attack_hand(mob/living/user)
	if(user.canUseTopic(src, be_close = 1))
		if(!total_accessable_power() >= 300)
			user << "<span class='warning'>[src] needs more power or replicant alloy to function!</span>"
			return 0
		toggle(0, user)

/obj/structure/clockwork/powered/mending_motor/attackby(obj/item/I, mob/user, params)
	if(istype(I, /obj/item/clockwork/component/replicant_alloy) && is_servant_of_ratvar(user))
		if(stored_alloy + 2500 > max_alloy)
			user << "<span class='warning'>[src] is too full to accept any more alloy!</span>"
			return 0
		user.whisper("Genafzhgr vagb jngre.")
		user.visible_message("<span class='notice'>[user] liquifies [I] and pours it onto [src].</span>", \
		"<span class='notice'>You liquify [src] and pour it onto [src], transferring the alloy into its reserves.</span>")
		stored_alloy = stored_alloy + 2500
		user.drop_item()
		qdel(I)
		return 1
	else
		return ..()



/obj/structure/clockwork/powered/mania_motor //Mania motor: A pair of antenna that, while active, cause braindamage and hallucinations in nearby human mobs.
	name = "mania motor"
	desc = "A pair of antenna with what appear to be sockets around the base. It reminds you of an antlion."
	clockwork_desc = "A transmitter that allows Sevtug to whisper into the minds of nearby non-servants, causing hallucinations and brain damage as long as it remains powered."
	icon_state = "mania_motor_inactive"
	active_icon = "mania_motor"
	inactive_icon = "mania_motor_inactive"
	construction_value = 20
	break_message = "<span class='warning'>The antenna break off, leaving a pile of shards!</span>"
	debris = list(/obj/item/clockwork/component/guvax_capacitor/antennae, /obj/item/clockwork/alloy_shards)
	var/mania_messages = list("\"Tb ahgf.\"", "\"Gnxr n penpx ng penml.\"", "\"Znxr n ovq sbe vafnavgl.\"", "\"Trg xbbxl.\"", "\"Zbir gbjneqf znavn.\"", "\"Orpbzr orjvyqrerq.\"", "\"Jnk jvyq.\"", \
	"\"Tb ebhaq gur oraq.\"", "\"Ynaq va yhanpl.\"", "\"Gel qrzragvn.\"", "\"Fgevir gb trg n fperj ybbfr.\"")
	var/compel_messages = list("\"Pbzr pybfre.\"", "\"Nccebnpu gur genafzvggre.\"", "\"Gbhpu gur nagraanr.\"", "\"V nyjnlf unir gb qrny jvgu vqvbgf. Zbir gbjneqf gur znavn zbgbe.\"", \
	"\"Nqinapr sbejneq naq cynpr lbhe urnq orgjrra gur nagraanr - gung'f nyy vg'f tbbq sbe.\"", "\"Vs lbh jrer fznegre, lbh'q or bire urer nyernql.\"", "\"Zbir SBEJNEQ, lbh sbby.\"")
	var/mania_cost = 150

/obj/structure/clockwork/powered/mania_motor/examine(mob/user)
	..()
	if(is_servant_of_ratvar(user) || isobserver(user))
		user << "<span class='sevtug_small'>It requires 150W of power to run, and 450W of power to convert humans adjecent to it.</span>"

/obj/structure/clockwork/powered/mania_motor/process()
	if(!..())
		visible_message("<span class='warning'>[src] hums loudly, then the sockets at its base fall dark!</span>")
		playsound(src, 'sound/effects/screech.ogg', 20, 1)
		toggle(0)
		return
	if(try_use_power(mania_cost))
		for(var/mob/living/carbon/human/H in range(10, src))
			if(!is_servant_of_ratvar(H))
				var/distance = get_dist(get_turf(src), get_turf(H))
				var/divided_distance = distance ? 100/distance : 100
				if(distance >= 4 && prob(divided_distance))
					H << "<span class='sevtug_small'>[pick(mania_messages)]</span>"
				switch(distance)
					if(0 to 1) //how did you get someone on top of it
						if(try_use_power(150))
							if(is_eligible_servant(H) && try_use_power(300))
								H << "<span class='sevtug'>\"Lbh ner zvar-naq-uvf, abj.\"</span>"
								add_servant_of_ratvar(H)
							else if(H.getBrainLoss() >= H.maxHealth && !H.stat)
								H.Paralyse(10)
								H <<"<span class='sevtug'>\"Lbh jba'g qb. Tb gb fyrrc juvyr V gryy gurfr avgjvgf ubj gb pbaireg lbh.\"</span>"
							else
								H.adjustBrainLoss(100)
						else
							visible_message("<span class='warning'>[src]'s antennae fizzle quietly.</span>")
							playsound(src, 'sound/effects/light_flicker.ogg', 50, 1)
					if(2 to 3)
						if(prob(divided_distance))
							if(prob(divided_distance))
								H << "<span class='sevtug_small'>[pick(mania_messages)]</span>"
							else
								H << "<span class='sevtug'>[pick(compel_messages)]</span>"
						H.adjustBrainLoss(divided_distance)
						H.adjust_drugginess(divided_distance)
						H.hallucination += divided_distance
					if(4 to 5)
						H.adjustBrainLoss(rand(10, 20))
						H.adjust_drugginess(rand(30, 40))
						H.hallucination += rand(30, 40)
					if(6 to 7)
						H.adjustBrainLoss(rand(5, 10))
						if(prob(100/distance))
							H.adjust_drugginess(rand(20, 30))
						else
							H.hallucination += rand(20, 30)
					if(8 to 9)
						H.adjustBrainLoss(rand(1, 5))
						if(prob(100/distance))
							H.adjust_drugginess(rand(10, 20))
						else
							H.hallucination += rand(10, 20)
					if(10)
						if(prob(100/distance))
							H.adjust_drugginess(rand(5, 10))
						else
							H.hallucination += rand(5, 10)
			else
				if(H.getBrainLoss() || H.hallucination || H.druggy)
					H.adjustBrainLoss(-H.getBrainLoss()) //heals
					H.hallucination = 0
					H.adjust_drugginess(-H.druggy)
	else
		visible_message("<span class='warning'>[src] hums loudly, then the sockets at its base fall dark!</span>")
		playsound(src, 'sound/effects/screech.ogg', 20, 1)
		toggle(0)
	return

/obj/structure/clockwork/powered/mania_motor/attack_hand(mob/living/user)
	if(user.canUseTopic(src, be_close = 1))
		if(!total_accessable_power() >= mania_cost)
			user << "<span class='warning'>[src] needs more power to function!</span>"
			return 0
		toggle(0, user)



/obj/structure/clockwork/powered/interdiction_lens //Interdiction lens: A powerful artifact that can massively disrupt electronics. Five-minute cooldown between uses.
	name = "interdiction lens"
	desc = "An ominous, double-pronged brass obelisk. There's a strange gemstone clasped between the pincers."
	clockwork_desc = "A powerful obelisk that can devastate certain electronics. It needs to recharge between uses."
	icon_state = "interdiction_lens"
	construction_value = 25
	active_icon = "interdiction_lens_inactive"
	inactive_icon = "interdiction_lens"
	break_message = "<span class='warning'>The lens flares a blinding violet before shattering!</span>"
	break_sound = 'sound/effects/Glassbr3.ogg'
	var/recharging = 0 //world.time when the lens was last used
	var/recharge_time = 3000 //time, in deciseconds, the lens needs to recharge; 5 minutes by default
	var/disrupt_cost = 1000 //how much power to use

/obj/structure/clockwork/powered/interdiction_lens/examine(mob/user)
	..()
	user << "<span class='[recharging >= world.time ? "alloy":"brass"]'>Its gemstone [recharging >= world.time ? "has been breached by writhing tendrils of blackness that cover the obelisk" \
	: "vibrates in place and thrums with power"]."

/obj/structure/clockwork/powered/interdiction_lens/attack_hand(mob/living/user)
	if(user.canUseTopic(src))
		disrupt(user)

/obj/structure/clockwork/powered/interdiction_lens/process()
	if(..() && recharging < world.time) //if we have power and have finished charging
		visible_message("<span class='warning'>The writhing tendrils return to the gemstone, which begins to glow with power.</span>")
		flick("[initial(icon_state)]_recharged", src)
		toggle()

/obj/structure/clockwork/powered/interdiction_lens/proc/disrupt(mob/living/user)
	if(!user || !is_servant_of_ratvar(user))
		return 0
	if(!total_accessable_power() >= disrupt_cost)
		user << "<span class='warning'>[src] needs more power to function!</span>"
		return 0
	if(active || recharging >= world.time)
		user << "<span class='warning'>As you place your hand on the gemstone, cold tendrils of black matter crawl up your arm. You quickly pull back.</span>"
		return 0
	user.visible_message("<span class='warning'>[user] places their hand on [src]' gemstone...</span>", "<span class='brass'>You place your hand on the gemstone...</span>")
	var/target = input(user, "Power flows through you. Choose where to direct it.", "Interdiction Lens") as null|anything in list("Disrupt Telecommunications", "Disable Cameras", "Disable Cyborgs")
	if(!user.canUseTopic(src) || !target)
		user.visible_message("<span class='warning'>[user] pulls their hand back.</span>", "<span class='brass'>On second thought, maybe not right now.</span>")
		return 0
	if(!try_use_power(disrupt_cost))
		user.visible_message("<span class='warning'>The len flickers once, but nothing happens.</span>", "<span class='heavy_brass'>The lens lacks the power to activate.</span>")
		return 0
	user.visible_message("<span class='warning'>Violet tendrils engulf [user]'s arm as the gemstone glows with furious energy!</span>", \
	"<span class='heavy_brass'>A mass of violet tendrils cover your arm as [src] unleashes a blast of power!</span>")
	user.notransform = TRUE
	icon_state = "[initial(icon_state)]_active"
	sleep(30)
	switch(target)
		if("Disrupt Telecommunications")
			for(var/obj/machinery/telecomms/hub/H in telecomms_list)
				for(var/mob/M in range(7, H))
					M << "<span class='warning'>You sense a strange force pass through you...</span>"
				H.visible_message("<span class='warning'>The lights on [H] flare a blinding yellow before falling dark!</span>")
				H.emp_act(1)
		if("Disable Cameras")
			for(var/obj/machinery/camera/C in cameranet.cameras)
				C.emp_act(1)
			for(var/mob/living/silicon/ai/A in living_mob_list)
				A << "<span class='userdanger'>Massive energy surge detected. All cameras offline.</span>"
				A << 'sound/machines/warning-buzzer.ogg'
		if("Disable Cyborgs")
			for(var/mob/living/silicon/robot/R in living_mob_list) //Doesn't include AIs, for obvious reasons
				if(is_servant_of_ratvar(R) || R.stat) //Doesn't affect already-offline cyborgs
					continue
				R.visible_message("<span class='warning'>[R] shuts down with no warning!</span>", \
				"<span class='userdanger'>Massive emergy surge detected. All systems offline. Initiating reboot sequence..</span>")
				playsound(R, 'sound/machines/warning-buzzer.ogg', 50, 1)
				R.Weaken(30)
	user.visible_message("<span class='warning'>The tendrils around [user]'s arm turn to an onyx black and wither away!</span>", \
	"<span class='heavy_brass'>The tendrils around your arm turn a horrible black and sting your skin before they shrivel away.</span>")
	user.notransform = FALSE
	recharging = world.time + recharge_time
	flick("[initial(icon_state)]_discharged", src)
	toggle()
	return 1



/obj/structure/clockwork/powered/clockwork_obelisk
	name = "clockwork obelisk"
	desc = "A large brass obelisk hanging in midair."
	clockwork_desc = "A powerful obelisk that can send a message to all servants or open a gateway to a target servant or clockwork obelisk."
	icon_state = "obelisk_inactive"
	active_icon = "obelisk"
	inactive_icon = "obelisk_inactive"
	construction_value = 20
	break_message = "<span class='warning'>The obelisk breaks apart in midair!</span>"
	debris = list(/obj/item/clockwork/alloy_shards)
	var/hierophant_cost = 50 //how much it costs to broadcast with large text
	var/gateway_cost = 2000 //how much it costs to open a gateway

/obj/structure/clockwork/powered/clockwork_obelisk/New()
	..()
	toggle(1)

/obj/structure/clockwork/powered/clockwork_obelisk/process()
	if(locate(/obj/effect/clockwork/spatial_gateway) in loc)
		icon_state = active_icon
		density = 0
	else
		icon_state = inactive_icon
		density = 1

/obj/structure/clockwork/powered/clockwork_obelisk/attack_hand(mob/living/user)
	if(!total_accessable_power() >= hierophant_cost)
		user <<  "<span class='warning'>You place your hand on the obelisk, but it doesn't react.</span>"
		return
	var/choice = alert(user,"You place your hand on the obelisk...",,"Hierophant Broadcast","Spatial Gateway","Cancel")
	switch(choice)
		if("Hierophant Broadcast")
			var/input = stripped_input(usr, "Please choose a message to send over the Hierophant Network.", "Hierophant Broadcast", "")
			if(user.canUseTopic(src, be_close = 1))
				if(try_use_power(hierophant_cost))
					send_hierophant_message(user, input, 1)
				else
					user <<  "<span class='warning'>The obelisk lacks the power to broadcast!</span>"
		if("Spatial Gateway")
			if(total_accessable_power() >= gateway_cost)
				if(procure_gateway(user, 100, 5, 1))
					user.say("Fcnpvny tngrjnl, npgvingr!")
					try_use_power(gateway_cost)
			else
				user <<  "<span class='warning'>The obelisk lacks the power to open a gateway!</span>"
		if("Cancel")
			return
