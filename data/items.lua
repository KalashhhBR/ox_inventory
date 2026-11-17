-- klsh: per-item grid fields (see CONFIG.md):
--   size = { width, height }   cells the item takes in a grid inventory (default 1 x 1)
--   maxStack = N               largest stack (false = no limit; default in data/grid.lua)
return {
	['testburger'] = {
		label = 'Test Burger',
		weight = 220,
		degrade = 60,
		client = {
			image = 'burger_chicken.png',
			status = { hunger = 200000 },
			anim = 'eating',
			prop = 'burger',
			usetime = 2500,
			export = 'ox_inventory_examples.testburger'
		},
		server = {
			export = 'ox_inventory_examples.testburger',
			test = 'what an amazingly delicious burger, amirite?'
		},
		buttons = {
			{
				label = 'Lick it',
				action = function(slot)
					print('You licked the burger')
				end
			},
			{
				label = 'Squeeze it',
				action = function(slot)
					print('You squeezed the burger :(')
				end
			},
			{
				label = 'What do you call a vegan burger?',
				group = 'Hamburger Puns',
				action = function(slot)
					print('A misteak.')
				end
			},
			{
				label = 'What do frogs like to eat with their hamburgers?',
				group = 'Hamburger Puns',
				action = function(slot)
					print('French flies.')
				end
			},
			{
				label = 'Why were the burger and fries running?',
				group = 'Hamburger Puns',
				action = function(slot)
					print('Because they\'re fast food.')
				end
			}
		},
		consume = 0.3
	},

	['bandage'] = {
		label = 'Bandage',
		weight = 115,
		client = {
			anim = { dict = 'missheistdockssetup1clipboard@idle_a', clip = 'idle_a', flag = 49 },
			prop = { model = `prop_rolled_sock_02`, pos = vec3(-0.14, -0.14, -0.08), rot = vec3(-50.0, -50.0, 0.0) },
			disable = { move = true, car = true, combat = true },
			usetime = 2500,
		}
	},

	['black_money'] = {
		label = 'Dirty Money',
	},

	['burger'] = {
		label = 'Burger',
		weight = 220,
		client = {
			status = { hunger = 200000 },
			anim = 'eating',
			prop = 'burger',
			usetime = 2500,
			notification = 'You ate a delicious burger'
		},
	},

	['sprunk'] = {
		label = 'Sprunk',
		weight = 350,
		client = {
			status = { thirst = 200000 },
			anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
			prop = { model = `prop_ld_can_01`, pos = vec3(0.01, 0.01, 0.06), rot = vec3(5.0, 5.0, -180.5) },
			usetime = 2500,
			notification = 'You quenched your thirst with a sprunk'
		}
	},

	['parachute'] = {
		label = 'Parachute',
		weight = 8000,
		stack = false,
		client = {
			anim = { dict = 'clothingshirt', clip = 'try_shirt_positive_d' },
			usetime = 1500
		}
	},

	['garbage'] = {
		label = 'Garbage',
	},

	['paperbag'] = {
		label = 'Paper Bag',
		weight = 1,
		stack = false,
		close = false,
		consume = 0
	},

	['identification'] = {
		label = 'Identification',
		client = {
			image = 'card_id.png'
		}
	},

	['panties'] = {
		label = 'Knickers',
		weight = 10,
		consume = 0,
		client = {
			status = { thirst = -100000, stress = -25000 },
			anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
			prop = { model = `prop_cs_panties_02`, pos = vec3(0.03, 0.0, 0.02), rot = vec3(0.0, -13.5, -1.5) },
			usetime = 2500,
		}
	},

	['lockpick'] = {
		label = 'Lockpick',
		weight = 160,
	},

	['phone'] = {
		label = 'Phone',
		weight = 190,
		stack = false,
		consume = 0,
		client = {
			add = function(total)
				if total > 0 then
					pcall(function() return exports.npwd:setPhoneDisabled(false) end)
				end
			end,

			remove = function(total)
				if total < 1 then
					pcall(function() return exports.npwd:setPhoneDisabled(true) end)
				end
			end
		}
	},

	['money'] = {
		label = 'Money',
	},

	['mustard'] = {
		label = 'Mustard',
		weight = 500,
		client = {
			status = { hunger = 25000, thirst = 25000 },
			anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
			prop = { model = `prop_food_mustard`, pos = vec3(0.01, 0.0, -0.07), rot = vec3(1.0, 1.0, -1.5) },
			usetime = 2500,
			notification = 'You.. drank mustard'
		}
	},

	['water'] = {
		label = 'Water',
		weight = 500,
		client = {
			status = { thirst = 200000 },
			anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
			prop = { model = `prop_ld_flow_bottle`, pos = vec3(0.03, 0.03, 0.02), rot = vec3(0.0, 0.0, -1.5) },
			usetime = 2500,
			cancel = true,
			notification = 'You drank some refreshing water'
		}
	},

	['radio'] = {
		label = 'Radio',
		weight = 1000,
		stack = false,
		allowArmed = true
	},

	['armour'] = {
		label = 'Bulletproof Vest',
		weight = 3000,
		size = { 3, 3 }, -- klsh: worn in the vest slot (see data/equipment.lua)
		maxStack = 1,
		stack = false,
		client = {
			anim = { dict = 'clothingshirt', clip = 'try_shirt_positive_d' },
			usetime = 3500
		}
	},

	['clothing'] = {
		label = 'Clothing',
		consume = 0,
	},

	['mastercard'] = {
		label = 'Fleeca Card',
		stack = false,
		weight = 10,
		client = {
			image = 'card_bank.png'
		}
	},

	['scrapmetal'] = {
		label = 'Scrap Metal',
		weight = 80,
	},

    -- klsh: clothing items (one per equipment slot; the piece itself is stored in metadata)
    ['clothing_hat'] = {
        label = 'Chapéu',
        weight = 150,
        size = { 2, 1 },
        maxStack = 1,
        stack = false,
        close = false,
        consume = 0,
    },

    ['clothing_mask'] = {
        label = 'Máscara',
        weight = 100,
        maxStack = 1,
        stack = false,
        close = false,
        consume = 0,
    },

    ['clothing_glasses'] = {
        label = 'Óculos',
        weight = 50,
        maxStack = 1,
        stack = false,
        close = false,
        consume = 0,
    },

    ['clothing_ears'] = {
        label = 'Brinco',
        weight = 20,
        maxStack = 1,
        stack = false,
        close = false,
        consume = 0,
    },

    ['clothing_neck'] = {
        label = 'Colar',
        weight = 80,
        maxStack = 1,
        stack = false,
        close = false,
        consume = 0,
    },

    ['clothing_top'] = {
        label = 'Jaqueta',
        weight = 600,
        size = { 2, 2 },
        maxStack = 1,
        stack = false,
        close = false,
        consume = 0,
    },

    ['clothing_undershirt'] = {
        label = 'Camiseta',
        weight = 250,
        size = { 2, 2 },
        maxStack = 1,
        stack = false,
        close = false,
        consume = 0,
    },

    ['clothing_gloves'] = {
        label = 'Luvas',
        weight = 100,
        maxStack = 1,
        stack = false,
        close = false,
        consume = 0,
    },

    ['clothing_pants'] = {
        label = 'Calça',
        weight = 500,
        size = { 2, 2 },
        maxStack = 1,
        stack = false,
        close = false,
        consume = 0,
    },

    ['clothing_shoes'] = {
        label = 'Sapatos',
        weight = 700,
        size = { 2, 1 },
        maxStack = 1,
        stack = false,
        close = false,
        consume = 0,
    },

    ['clothing_watch'] = {
        label = 'Relógio',
        weight = 100,
        maxStack = 1,
        stack = false,
        close = false,
        consume = 0,
    },

    ['clothing_bracelet'] = {
        label = 'Pulseira',
        weight = 50,
        maxStack = 1,
        stack = false,
        close = false,
        consume = 0,
    },

    -- klsh: outfit bag (keeps one look; rules in data/equipment.lua, `outfitBag`)
    ['outfit_bag'] = {
        label = 'Bolsa de estilo',
        weight = 500,
        size = { 3, 2 },
        maxStack = 1,
        stack = false,
        close = true,
        consume = 0,
        client = {
            image = 'clothing_bag.png',
        },
    },

    -- klsh: backpacks (containers worn in the bag slot; capacity and weight reduction in data/equipment.lua)
    ['backpack_small'] = {
        label = 'Mochila pequena',
        weight = 400,
        size = { 2, 2 },
        maxStack = 1,
        stack = false,
        close = false,
        consume = 0,
        client = {
            image = 'clothing_bag.png',
        },
    },

    ['backpack_medium'] = {
        label = 'Mochila',
        weight = 800,
        size = { 3, 3 },
        maxStack = 1,
        stack = false,
        close = false,
        consume = 0,
        client = {
            image = 'clothing_bag.png',
        },
    },

    ['backpack_large'] = {
        label = 'Mochila grande',
        weight = 1200,
        size = { 4, 3 },
        maxStack = 1,
        stack = false,
        close = false,
        consume = 0,
        client = {
            image = 'clothing_bag.png',
        },
    },
}
