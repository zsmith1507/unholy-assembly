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
