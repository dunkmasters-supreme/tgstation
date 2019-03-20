// Potato
/obj/item/seeds/potato
	name = "pack of potato seeds"
	desc = "Boil 'em! Mash 'em! Stick 'em in a stew!"
	icon_state = "seed-potato"
	species = "potato"
	plantname = "Potato Plants"
	product = /obj/item/weapon/reagent_containers/food/snacks/grown/potato
	lifespan = 30
	maturation = 10
	production = 1
	yield = 4
	growthstages = 4
	icon_grow = "potato-grow"
	icon_dead = "potato-dead"
	genes = list(/datum/plant_gene/trait/battery)
	mutatelist = list(/obj/item/seeds/potato/sweet)
	reagents_add = list("vitamin" = 0.04, "nutriment" = 0.1)

/obj/item/weapon/reagent_containers/food/snacks/grown/potato
	seed = /obj/item/seeds/potato
	name = "potato"
	desc = "Boil 'em! Mash 'em! Stick 'em in a stew!"
	icon_state = "potato"
	filling_color = "#E9967A"
	bitesize = 100

// Sweet Potato
/obj/item/seeds/potato/sweet
	name = "pack of sweet potato seeds"
	desc = "These seeds grow into sweet potato plants."
	icon_state = "seed-sweetpotato"
	species = "sweetpotato"
	plantname = "Sweet Potato Plants"
	product = /obj/item/weapon/reagent_containers/food/snacks/grown/potato/sweet
	mutatelist = list()
	reagents_add = list("vitamin" = 0.1, "sugar" = 0.1, "nutriment" = 0.1)

/obj/item/weapon/reagent_containers/food/snacks/grown/potato/sweet
	seed = /obj/item/seeds/potato/sweet
	name = "sweet potato"
	desc = "It's sweet."
	icon_state = "sweetpotato"