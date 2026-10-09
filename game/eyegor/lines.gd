extends RefCounted
## Every player-facing word in the slice, keyed by line id. Owned by the Eyegor and HUD department.
## How Eyegor writes is in VOICE.md. Get a line with Narrative.line("key", {args}).
##
## A value is a String or an Array of Strings (Narrative picks one variant at random).
## {name} placeholders are filled from the args Dictionary.
## Key families:
##   obj_<id> / intro_<id> / done_<id> / milestone_<id>   the hidden-start objectives (objectives.gd)
##   item_<kind>, item_part_<part>                          describe_item()
##   build_<kind>, desc_<kind>, hint_<verb>                 machines and interact hints (Lair may use these)
##   spell_<id>                                             spell names (Necromancer may use these)
##   memo_<topic>                                           HR memos; the first line "RE: ..." is the subject
##   hud_*, title_*, pause_*, controls_*                    screen labels

const MISSION := "Bringing Eternal Life to a Village Near You, Since 1197."

const LINES := {
	# ------------------------------------------------------------ the company
	"mission": MISSION,
	"game_title": "Unholy Assembly",
	"advisor_name": "Eyegor",
	"advisor_title": "Director of Undying Resources",
	"memo_header": "MEMO",
	"memo_signoff": "Eyegor, Director of Undying Resources",
	"banner_milestone": "Milestone Reached",
	"banner_all_done": "Onboarding Complete",

	# ------------------------------------------------------------ title, loading, pause, controls
	"title_begin": "Begin",
	"title_controls": "Controls",
	"title_quit": "Quit",
	"title_prompt": "Press {key} to begin",
	"loading": [
		"Loading. Please hold. Your afterlife is important to us.",
		"Digging graves. Mostly other people's.",
		"Polishing the clipboard.",
		"Counting souls. Then counting them again.",
	],
	"pause_title": "Paused",
	"pause_subtitle": "The dead can wait. They're very good at it.",
	"pause_resume": "Resume",
	"pause_controls": "Controls",
	"pause_quit": "Quit to Desktop",
	"controls_title": "Controls",
	"controls_back": "Back",
	"controls_keyboard": "Keyboard & Mouse",
	"controls_gamepad": "Gamepad",
	"ctl_move": "Move",
	"ctl_jump": "Jump",
	"ctl_cast": "Cast spell",
	"ctl_cast_alt": "Cancel / alternate",
	"ctl_aim": "Aim",
	"ctl_interact": "Interact",
	"ctl_spells": "Change spell",
	"ctl_advisor": "Eyegor's clipboard",
	"ctl_pause": "Pause",

	# ------------------------------------------------------------ HUD labels
	"hud_mana": "Mana",
	"hud_heart": "Heart",
	"hud_no_heart": "No heart yet",
	"hud_fragments": "Fragments",
	"hud_suspicion": "Suspicion",
	"hud_hunger": "Hunger",
	"hud_day": "Day {day}",
	"hud_objective": "Objective",
	"hud_soul_unit": "soul",
	"hud_souls_unit": "souls",
	"phase_dawn": "Dawn",
	"phase_day": "Day",
	"phase_dusk": "Dusk",
	"phase_night": "Night",
	"popup_soul": "+{amount} soul",
	"popup_souls": "+{amount} souls",
	"popup_fragment": "+1 fragment",
	"popup_fragments": "+{amount} fragments",
	"clipboard_title": "Onboarding Checklist",
	"clipboard_log": "Recent Correspondence",
	"clipboard_close": "{key} to close",

	# ------------------------------------------------------------ the hidden-start objectives
	"intro_place_heart": "Good evening, Master, and welcome aboard! First item on the agenda: dig in and place your Necrotic Heart somewhere cosy and underground.",
	"obj_place_heart": "Place your Necrotic Heart underground",
	"done_place_heart": "The Heart is in! Beating, glowing, and entirely ours. Every great enterprise starts with a single organ.",
	"milestone_place_heart": "Headquarters Established",

	"intro_refill_mana": "Your mana is measured in souls, Master. When it runs low, step up to the Heart and draw on the souls stored there.",
	"obj_refill_mana": "Refill your mana at the Heart",
	"done_refill_mana": "Topped up! One soul, fully reinvested. That's what I call liquidity.",
	"milestone_refill_mana": "Liquidity Achieved",

	"intro_dig_chamber": "Next, office space! Carve out a chamber around the Heart with your Dig spell. Open plan, very modern, no windows.",
	"obj_dig_chamber": "Dig out your first chamber",
	"done_dig_chamber": "Look at all that floor space! I'll put in a request for a water cooler. Or a blood cooler.",
	"milestone_dig_chamber": "Office Space Acquired",

	"intro_rob_grave": "Time for talent acquisition! The town cemetery is full of candidates with excellent references. Draw one up through the earth with Harvest.",
	"obj_rob_grave": "Rob a grave in the town cemetery",
	"done_rob_grave": "Welcome aboard! This candidate was resting, but frankly showed real potential.",
	"milestone_rob_grave": "First Hire",

	"intro_build_grinder": "Our recruit needs onboarding. Build a Corpse Grinder in the lair. It turns one large employee into many small, useful ones.",
	"obj_build_grinder": "Build a Corpse Grinder",
	"done_build_grinder": "The Grinder is installed! Please keep hands, feet and Eyegors clear of the intake.",
	"milestone_build_grinder": "Heavy Industry",

	"intro_grind_corpse": "Feed a body into the Grinder. Think of it as restructuring.",
	"obj_grind_corpse": "Grind a corpse",
	"done_grind_corpse": "Restructuring complete! Parts, gibs and bones, all sorted. Nothing goes to waste here. Except, technically, everyone.",
	"milestone_grind_corpse": "Restructuring Complete",

	"intro_build_stitching_table": "Now we need assembly. Build a Stitching Table, where parts become personnel.",
	"obj_build_stitching_table": "Build a Stitching Table",
	"done_build_stitching_table": "Stitching Table ready! Needles threaded, thread also threaded. I'm told that's how it works.",
	"milestone_build_stitching_table": "Assembly Line",

	"intro_stitch_body": "Bring parts to the Stitching Table and stitch a whole body. It doesn't have to match. Diversity of parts is a strength!",
	"obj_stitch_body": "Stitch together a body",
	"done_stitch_body": "A complete body! Two arms, two legs, one head. I checked twice. Well, once. I only have the one eye.",
	"milestone_stitch_body": "Some Assembly Required",

	"intro_build_altar": "The body is ready. It just lacks motivation. Build a Reanimation Altar.",
	"obj_build_altar": "Build a Reanimation Altar",
	"done_build_altar": "The Altar is up! It smells faintly of ozone and regret. Lovely.",
	"milestone_build_altar": "Motivation Department",

	"intro_raise_ghoul": "Lay the body on the Altar and spend a soul to raise it. Every employee costs at least one soul. Very competitive salary!",
	"obj_raise_ghoul": "Raise your first ghoul",
	"done_raise_ghoul": "It lives! Well, it ghouls. Please welcome our newest team member, who works tirelessly because it physically cannot tire.",
	"milestone_raise_ghoul": "Our First Employee",

	"intro_mark_dig": "A good manager delegates. Mark ground with the Dig command and your ghouls will clear it. You point; they dig.",
	"obj_mark_dig": "Mark ground for your ghouls to dig",
	"done_mark_dig": "Delegation! I'm writing 'natural leader' on your review right now.",
	"milestone_mark_dig": "Middle Management",

	"intro_harvest_fragments": "Souls don't grow on trees, Master. They grow in rabbits. Go to the forest and harvest soul fragments from a critter. Five make a whole soul.",
	"obj_harvest_fragments": "Harvest soul fragments from a critter",
	"done_harvest_fragments": "A fragment! Small, but it adds up. Every rabbit is a micro-investment.",
	"milestone_harvest_fragments": "Diversified Portfolio",

	"intro_survive_patrol": "Heads up, Master: a patrol of community stakeholders is on its way. Stay out of sight, or make sure nobody reports back.",
	"obj_survive_patrol": "Survive the first farmer patrol",
	"done_survive_patrol": "The patrol has gone! Home, or to a better place. I couldn't say, and I certainly won't write it down.",
	"milestone_survive_patrol": "Community Relations",

	"all_done": "That's the whole onboarding checklist, Master! Your performance review is glowing. Literally; I spilled ectoplasm on it.",

	# ------------------------------------------------------------ running commentary
	"first_soul": "A soul for the Heart! Deposited, logged, and filed under Assets.",
	"soul_banked": [
		"Another soul banked!",
		"Soul received. The Heart thanks you for your business.",
		"Deposit confirmed. Our reserves grow!",
	],
	"mana_low": "Mana's running low, Master. Pop back to the Heart for a top-up.",
	"night_started": "Night shift, Master! The best shift. Fewer witnesses, more opportunities.",
	"day_started": "The sun is up. Our least favourite colleague. Best keep things quiet until dusk.",
	"suspicion_25": "The village is showing some interest in our brand, Master. Wonderful for awareness. Less wonderful for us.",
	"suspicion_50": "People are talking, Master. People are holding pitchforks while talking. Let's lie low for a bit.",
	"suspicion_75": "I have some concerns, and by 'some' I mean torches. Suspicion is very high. Perhaps a quiet night in?",
	"hunger_25": "Our partners downstairs have noticed our soul collection. They've sent a very warm greeting. Literally warm.",
	"hunger_50": "Something deep below is taking an interest in our numbers. I've listed it on the clipboard as a stakeholder.",
	"hunger_75": "The scratching under the floor is getting louder, Master. I'm sure it's just the plumbing. We don't have plumbing.",
	"sighting": "Someone saw something they shouldn't have, Master. Perhaps they'd like to join the company?",
	"human_killed_witnessed": "Their soul is ours! Witnessed, collected and countersigned.",
	"human_killed_unwitnessed": "A death without you there, Master, so the soul slipped away. Someone has to be present to sign for the delivery!",
	"heart_destroyed": "The Heart is gone, Master. That's... not ideal! But it is data. Let's find a new site and start again.",
	"minion_raised": [
		"Another hire! The team grows.",
		"New starter on the floor! I've given it a name badge. It ate the name badge.",
		"Welcome to the team! Benefits include not being dead. Mostly.",
	],

	# ------------------------------------------------------------ HR memos (Lair sends these with mood &"memo")
	"memo_rest": "RE: Rest\nThe ghouls have asked, politely, for somewhere to lie down that isn't the floor. Coffin bunks would do wonders for morale.",
	"memo_food": "RE: Rations\nSeveral ghouls report they are hungry. One reports he is eating his colleague. Please arrange meat before this becomes policy.",
	"memo_overtime": "RE: Hours\nA reminder that ghouls are owed rest. I have received a complaint written in what I hope was ink.",
	"memo_seating": "RE: Seating\nThe ghouls have asked for somewhere to sit that isn't another ghoul. I have noted it on the clipboard.",
	"memo_slowdown": "RE: Productivity\nOutput is down. The ghouls say they are 'working to rule'. I didn't know we had rules. Apparently we do now.",
	"memo_strike": "RE: Industrial Action\nThe ghouls are on strike. There are picket signs. One is spelled correctly. Please see to their needs, Master.",

	# ------------------------------------------------------------ items (describe_item)
	"item_corpse": [
		"Corpse, Pre-Owned. One careful owner.",
		"Body, Gently Deceased. Sold as seen. No returns.",
	],
	"item_part": "Part, Assorted. Fits somewhere. Probably.",
	"item_part_arm": "{side}Arm, Slightly Used. Previous owner no longer requires it.",
	"item_part_leg": "{side}Leg, Low Mileage. Walked mostly on Sundays.",
	"item_part_head": "Head, Vacant. Ideal for a role that requires no thinking.",
	"item_part_torso": "Torso, Load-Bearing. The middle of everything.",
	"item_gibs": "Gibs, Bulk. Sold by the bucket. Ask about our loyalty scheme.",
	"item_bones": "Bones, Structural. The original frame, minus the furnishings.",
	"item_stitched_body": "Body, Assembled. Some assembly was required. Some remains optional.",
	"item_meat": "Meat, Unspecified. Don't ask. The ghouls didn't.",
	"item_metal": "Metal, Scrap. Formerly a plough, a pot, or a very unlucky knight.",
	"item_wood": "Wood, Seasoned. Formerly a tree, a door, or a coffin. We recycle.",
	"item_stone": "Stone, Unremarkable. Great for walls. Poor conversationalist.",
	"item_soul_orb": "Soul, Loose. Please return it to the Heart at your earliest convenience.",
	"item_unknown": "{name}, Condition Unknown. It's ours now, whatever it is.",

	# ------------------------------------------------------------ buildings and interact hints (for Lair)
	"build_heart": "Necrotic Heart",
	"build_grinder": "Corpse Grinder",
	"build_stitching_table": "Stitching Table",
	"build_altar": "Reanimation Altar",
	"build_spike_trap": "Spike Trap",
	"desc_heart": "The beating centre of the company. Stores souls; draws attention from above and below.",
	"desc_grinder": "Turns a body into parts, gibs and bones. Mind the intake.",
	"desc_stitching_table": "Where parts become personnel.",
	"desc_altar": "Spend a soul; gain an employee.",
	"desc_spike_trap": "A warm welcome for uninvited guests.",
	"hint_refill": "Refill mana",
	"hint_grind": "Load grinder",
	"hint_stitch": "Stitch body",
	"hint_raise": "Raise ghoul",
	"hint_pick_up": "Pick up",

	# ------------------------------------------------------------ spells (for the Necromancer)
	"spell_dig": "Dig",
	"spell_harvest": "Harvest",
	"spell_siphon": "Siphon",
	"spell_build": "Build",
	"spell_command_dig": "Dig Order",
	"spell_stockpile": "Stockpile",
	"spell_raise": "Raise",
}
