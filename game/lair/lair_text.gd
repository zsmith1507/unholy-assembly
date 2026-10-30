class_name LairText
extends RefCounted
## Every line the Lair says, in one place. Each goes through `Narrative.line(key)` first, so the Eyegor
## department can rewrite any of them by key; until it does, the default below is used.

const LINES := {
	"heart_refill": "The heart gives up {souls} soul's worth. Your mana is topped up.",
	"heart_refill_empty": "The heart is empty, sire. No souls to spare.",
	"heart_refill_full": "Your mana is already full, sire.",
	"hint_heart": "Necrotic Heart ({souls} souls): refill mana",
	"hint_altar_raise": "Reanimation Altar: raise a {minion}",
	"hint_altar_empty": "Reanimation Altar (empty): switch to {minion}",
	"altar_mode": "The altar will raise a {minion} next.",
	"altar_no_soul": "The heart has no soul to spare for this one.",
	"altar_no_mana": "You lack the mana to lay hands on it, sire.",
	"altar_raised": "It twitches. It stands. Another {minion} joins the payroll.",
	"hint_machine": "{name}: {status}",
	"status_working": "working",
	"status_waiting": "waiting for {needs}",
	"status_ready": "ready, wants an operator",
	"stockpile_refused": "Raw parts can't go in a stockpile. Grind them first. Regulations.",
	"stockpile_made": "A new {kind} stockpile. The ghouls will keep it tidy. Ish.",
	"dig_needs_tools": "The ghouls can't dig stone bare-handed. They'll need metal tools.",
	"memo_complaint": "MEMO: The ghouls have raised concerns about {need}. I have filed them.",
	"memo_slowdown": "MEMO: The ghouls are working to rule. Output is down.",
	"memo_strike": "MEMO: The ghouls are on strike. There are signs. They are spelled wrong.",
	"memo_strike_over": "MEMO: The strike is over. The ghouls return to work. Grudgingly.",
	"memo_motivated": "MEMO: Morale has improved after your visit. Nobody is to discuss the visit.",
	"need_food": "food",
	"need_rest": "rest",
	"hint_striker": "Striking ghoul: pay a motivational visit",
	"heart_destroyed": "The heart is gone. Everything it fed is going with it.",
	# build menu (Eyegor's lines build_<kind> / desc_<kind> win when present)
	"build_heart": "Necrotic Heart",
	"build_grinder": "Corpse Grinder",
	"build_stitching_table": "Stitching Table",
	"build_altar": "Reanimation Altar",
	"build_spike_trap": "Spike Trap",
	"desc_heart": "The heart of the lair. Stores souls, refills your mana, and everything is built in its reach. The first one is free.",
	"desc_grinder": "Ghouls feed it corpses and parts; it turns them into gibs and bones. Loud.",
	"desc_stitching_table": "Bring flesh and bones in your satchel and stitch a body. Ghouls can feed it gibs and bones too.",
	"desc_altar": "Lay a stitched body on it, or carry one in your satchel, and touch it to raise a minion. Costs a soul.",
	"desc_spike_trap": "Skewers anything living that steps on it, then re-arms.",
	# satchel
	"hint_table_stitch": "Stitching Table: stitch a body ({recipe})",
	"hint_table_needs": "Stitching Table: needs {missing}",
	"table_stitch": "Flesh and bone, on the table. Give it a moment.",
	"table_needs": "Not enough to stitch a body, sire. It needs {missing}.",
	"hint_altar_satchel": "Reanimation Altar: lay your stitched body down and raise a {minion}",
	"hint_altar_needs_soul": "Reanimation Altar: needs a soul in the heart",
	"hint_altar_needs_mana": "Reanimation Altar: needs {mana} mana for your touch",
	"hint_altar_first": "Reanimation Altar: raise your first {minion} (the heart spares this soul)",
	"altar_first_free": "The heart spares a soul for your first. Don't get used to it.",
	"hint_grinder": "Corpse Grinder: {status} (ghouls feed it)",
	"hint_body_pick_up": "Stitched body: put it in your satchel",
	"body_picked_up": "A stitched body, folded neatly into the satchel. Mostly neatly.",
	"satchel_full": "The satchel is full, sire.",
	"more_of": "{n} more {kind}",
	"minion_soul_lost": "One of ours fell beyond the heart's reach. Its soul is loose out there.",
}


## The line for `key`, with {placeholders} filled from `args`.
static func t(key: String, args: Dictionary = {}) -> String:
	var s := Narrative.line(key, args)
	if s == key.format(args) and LINES.has(key):
		s = String(LINES[key]).format(args)
	return s


## Have Eyegor say the line for `key`.
static func say(key: String, mood: StringName = &"chipper", args: Dictionary = {}) -> void:
	Narrative.say(t(key, args), mood)
