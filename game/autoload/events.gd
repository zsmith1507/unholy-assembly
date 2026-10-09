extends Node
## Signal bus. Departments talk to each other through these signals instead of holding references.
## Add a signal here when two departments need to talk; keep the argument lists stable once others use them.

# --- souls and mana ---
signal soul_collected(amount: float, source: String, at: Vector2) ## a soul or fragment reached the heart
signal souls_changed(souls: float) ## the heart's store changed
signal mana_changed(mana: float, max_mana: float) ## in souls' worth
signal soul_orb_dropped(orb: Node2D) ## a minion died outside the heart's range

# --- deaths and bodies ---
signal actor_died(actor: Node2D, killer: Node2D, at: Vector2)
signal human_killed(actor: Node2D, witnessed_by_necromancer: bool)
signal body_harvested(item: Node2D) ## a corpse or part reached the necromancer's hand

# --- the lair ---
signal heart_placed(at: Vector2, radius: float)
signal heart_destroyed(at: Vector2)
signal machine_built(machine: Node2D)
signal item_produced(kind: StringName, amount: int, at: Vector2) ## e.g. &"gibs", &"bones", &"stitched_body"
signal minion_raised(minion: Node2D)
signal stockpile_designated(rect: Rect2i, kind: StringName)
signal dig_marked(cells: Rect2i)

# --- threat ---
signal suspicion_changed(value: float, delta: float, reason: String)
signal hunger_changed(value: float, delta: float, reason: String)
signal noise_made(at: Vector2, loudness: float, source: String) ## Threats turns this into Suspicion
signal sighting(witness: Node2D, of: Node2D) ## a living human saw something undead

# --- world ---
signal time_of_day_changed(hour: float, is_night: bool)
signal day_started(day: int)
signal night_started(day: int)

# --- spells and the player ---
signal spell_selected(spell_id: StringName)
signal spell_cast(spell_id: StringName, at: Vector2)

# --- narrative ---
signal milestone_reached(id: StringName) ## Eyegor reacts, the HUD announces
signal advisor_line(text: String, mood: StringName) ## something wants Eyegor to say a line
