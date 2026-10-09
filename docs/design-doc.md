# Unholy Assembly — Design Document

Oct 7, 2026 · @Zach

## Overview

The player is a necromancer, an intruder in a land that wants him dead. He digs a hidden lair beneath a forest, steals corpses, and grows an undead factory and army until he can conquer both the holy fortress above and the demons' citadel below.

- **Genre:** 2D side-scrolling factory/automation sim on diggable, destructible terrain.
- **Plays like:** Satisfactory for building, automating and scaling up, with Noita's controls, movement and hands-on combat.
- **Looks like:** Noita's pixel-simulated world, painted in Darkest Dungeon's grime and lit by cold necrotic glow.
- **Feels like:** grim on the surface, with plenty of gallows humor underneath.

### Design pillars

1. **Squeezed from above and below.** Activity on the surface draws the forces of "good." Collecting souls and digging deep draws demons and old gods. The necrotic heart at the center of the lair attracts both, and has to survive both.
2. **Build hidden, then build big.** The game opens as a stealthy intruder story, where traps and lures pick off lone humans because open fights are too dangerous. It grows into an industrial-scale operation with an army to match.
3. **Magic, never manual labor.** The necromancer commands; his minions work. He digs and raises with a wave of his hand, never a shovel. Souls are only collected when he is present at a death, so he still has to go out into the world.
4. **Horror delivered cheerfully.** The systems are serious; the writing treats a death factory like an upbeat small business.

### The company and its advisor

The necromancer's operation is run like a company. Its mission statement: **"Bringing Eternal Life to a Village Near You, Since 1197."** It appears on loading screens, memos, milestone banners and the occasional recruitment poster nailed to a ruined church door.

The advisor is **Eyegor**, the company's **Director of Undying Resources**. He checks in on the necromancer, tells him what a wonderful job he is doing, and describes the horrors being committed with a relentlessly positive corporate demeanor. He fills the role ADA plays in Satisfactory: tutorials, quotas, milestone unlocks and running commentary.

- **Look:** a single floating eye with black feathered wings, holding a clipboard and a feather quill up in front of himself. He reads every status report off the clipboard. Eye, wings, clipboard and quill are his whole silhouette, so he reads clearly even at Steam Deck size.
- **Rendering:** Eyegor is a UI character, not part of the simulated world, so his sprite gets more detail than the terrain. That keeps the clipboard and quill legible.
- **Name:** a pun on the classic hunchbacked lab assistant. Other names considered: Toothy, Peepers, Chipper, Sunny, Smiles.

## Art direction

Every pixel is a simulated material seen from the side, painted dark and grimy, with bright color reserved for magic.

- **Rendering:** Noita-style pixel material simulation (soil, stone, bone, blood, ichor, fire, smoke) rather than tile-based blocks. Materials fall, flow, burn and mix.
- **Palette by depth:** Darkest Dungeon's warm grime (browns, dried-blood reds, sickly greens) on the surface. Cold teal necrotic glow takes over underground and around necromancy, with purple creeping in near the old gods. The deeper you go, the colder and stranger it gets.
- **Palette by prosperity:** early towns are poor and grimy. More advanced towns look noticeably nicer (cleaner stone, warm windows, banners), so a richer town reads as a richer target at a glance. Homes visibly decay when their residents die (see World: Settlements).
- **Lighting:** dark by default. Torches, braziers, glowing machines and spells carve pools of light out of the dark.
- **Characters and machines:** chunky pixel sprites with exaggerated, slightly comic animation (twitching corpses, stitched minions lurching off conveyors).
- **Stench:** a faint, browning-green scent wave drifts off anything that smells of death, so the player can see what might give the lair away (see Factory: Staying hidden).

### Sprite style

| Choice | Decision |
| --- | --- |
| Size | Large and detailed: about 64 px tall or more, in the spirit of Dead Cells |
| Outlines | Dark outlines, so characters pop against dark backgrounds on the Steam Deck |
| Proportions | Lanky and exaggerated, Darkest Dungeon-style: long limbs, hunched shapes, grim but comic |
| Shading | Flat colors on the sprites; real-time light pools and glow do the mood work |

**Scale note:** in Noita, characters are tiny because every terrain pixel is a simulated cell. With large sprites, simulating terrain at that same fine detail would mean far more cells on screen, which is costly on a Steam Deck. Proposed: simulate terrain at a coarser grain (each cell drawn as a 2×2 or 4×4 block of screen pixels) while characters keep their full detail. The falling-sand test should try both.

### Reference: the teal throne room

Zach's first reference image shows a tiny knight facing a towering eldritch figure beside a glowing portal. What to take from it:

- Teal-dominant lighting with near-black shadows.
- Huge scale contrast between the player and what lives below.
- Drifting particles and mist that give depth to a flat side view.
- A single strong light source that frames the whole scene.

### Magic schools and their colors

Zach set green, orange and blue; the rest are proposals.

| Color | School | Notes |
| --- | --- | --- |
| Teal | Necromancy and souls | The necromancer's signature; raising, soul capture |
| Green | Toxic and plague | Poison clouds, rot, disease |
| Orange | Fire | Proposed as hellfire, tied to the demons below |
| Blue | Frost | Grave-cold, slowing and freezing |
| Purple | Void and the old gods | Madness, tentacles, things from the deep |
| Crimson | Blood magic | Spend health or gibs for power |
| White-gold | Holy (enemy only) | The only clean, bright light in the game belongs to the forces of "good" |

## Tone and humor

The world looks bleak and the systems are played straight; the jokes come from treating a death factory like an upbeat, slightly dysfunctional business.

- **The advisor:** the main comedic voice, cheerfully narrating atrocities (see Overview).
- **Corporate necromancy:** quotas, productivity memos, "Employee of the Month" for the zombie that lost the fewest limbs.
- **Flavor text:** deadpan item and machine descriptions ("Left Arm, Slightly Used. Previous owner no longer requires it.").
- **Mismatched parts:** zombies built from whatever came down the belt, so a knight's torso on a farmer's legs walks a bit differently.
- **The forces of "good":** pompous, preachy and not as heroic as they think.
- **Ghoul labor relations:** workers who complain, unionize and strike. This is a real mechanic, not just flavor (see Minions).

### Content boundaries

- **No children on screen.** Children can exist as a concept in the world (a town's population, flavor text), but they never appear visually and the player never kills kids. Every human the player can harvest or fight is an adult.
- Proposed: gore stays stylized and pixel-chunky rather than realistic, so the humor lands and the game stays within a mainstream Steam rating.

## World

The world is procedurally generated, fully diggable, and layered: humans rule the surface, the necromancer hides in the middle, and older, worse things wait below.

### Starting area

The necromancer starts outdoors in a forest biome of rolling hills, with a small town in each direction. The player picks where to dig in their first base. Low-level patrols (farmers and the like) wander the surface, pushing the player to hide underground. The forest is full of small critters, the necromancer's first source of soul fragments. The tone from the first minute: you are an intruder in these lands.

### Map and biomes

Maps are big, on the scale of Terraria. The forest start sits in the middle, and new biomes appear as the player travels left or right, ending at the coast on both edges.

Every biome has human life, but how much varies, so each one feels distinct. Every biome gets two towns. Cities appear in most biomes, rarely in the snowy and desert biomes, and never in the swamp. Towns sit far enough from their city that the necromancer has to travel or dig to get between them.

| Biome | Human life | Settlements | Flavor |
| --- | --- | --- | --- |
| Forest (start) | Common | A city plus two towns; a small town in each direction from the start | Rolling hills and cover; the safest place to dig in |
| Plains | Abundant | A city plus two towns | Farmland and villages; easy pickings, but open sight lines make it hard to hide |
| Snowy | Sparse | Towns; a city only rarely | Frozen bodies don't rot; frost-magic materials; hardy, isolated folk |
| Desert | Sparse | Towns; a city only rarely | Dry bodies make excellent bone; buried tombs and mummies |
| Swamp | Very rare | No city; a shack or two of leech fishers | A natural hideout with nobody watching |
| Coastal | Moderate | Fishing towns at the far edge of the map on either side | Drowned sailors, shipwrecks, the end of the world |

**The leech fishers:** instead of a city, the swamp holds a tiny, grotesque fishing village, a shack or two of people who fish the bog for leeches. They're the only human life in the biome: barely watched, and a steady trickle of bodies that won't draw a city's attention.

### Layers

| Depth | What's there | Threat |
| --- | --- | --- |
| Surface | Biomes, towns, cities, the holy fortress | Patrols, city guards, holy forces hunting you |
| Shallow underground | The lair, the necrotic heart and workshops | Raids that find you; noise that carries to the surface; floods you cause yourself |
| Deep underground | Ancient graveyards, catacombs, rarer materials | Old horrors, growing stronger with depth |
| The deep | Old gods; the demons' unholy citadel | Dig too far and you unleash a new tier of threat that stays for the rest of the game (Mines of Moria style) |

### Settlements

Every home in a human settlement tracks whether its resident is still alive.

- **Decay:** when a resident dies, the home slowly runs down and stands empty. A raided town visibly rots over time.
- **Repopulation:** settlements slowly repopulate, and homes grow bigger again.
- **Farming a village:** early on, the player can cull a town sustainably instead of wiping it out, taking a few bodies at a time and letting it recover.
- Proposed: richer towns produce better bodies (soldiers and knights instead of farmers), so letting a town grow can pay off later.
- Proposed: a town that shrinks too fast raises Suspicion, while slow, careful culling stays under the radar.

### Procedural spawns

Each world is generated with a mix of these finds, so exploration is always worth the risk. All are proposals: check off the ones to keep.

**Surface**

- [ ] **Old battlefield:** a one-time haul of ancient parts and rusty metal. *Risk:* restless dead that weren't raised by you.
- [ ] **Haunted graveyard** (near towns): free souls drifting as ghosts. *Risk:* they flee and are hard to catch until soul pull is unlocked.
- [ ] **Gallows hill** (near towns): fresh bodies on a steady schedule. *Risk:* watched by the town guard.
- [ ] **Abandoned chapel:** holy relics to destroy or corrupt for power. *Risk:* consecrated ground burns undead.
- [ ] **Wandering merchant** (roads): trades rare goods, no questions asked. *Risk:* reports you if Suspicion is high.
- [ ] **Haunted manor** (new): fleeing ghost souls plus a rich family's valuables. *Risk:* a poltergeist that wrecks minions.
- [ ] **Monster hunters' camp** (new): holy weapons and armor to loot. *Risk:* the hunters are trained to fight undead.
- [ ] **Rival necromancer** (new): a wandering apprentice whose minions you can steal. *Risk:* he steals yours.

**Biome-specific (new)**

- [ ] **Critter warren** (forest): a dense patch of critters for soul fragments. *Risk:* a druid protector.
- [ ] **Frozen battlefield** (snowy): perfectly preserved soldiers' bodies. *Risk:* thin ice over freezing water.
- [ ] **Mummy tomb** (desert): preserved bodies with excellent bone. *Risk:* curse traps.
- [ ] **Bog bodies** (swamp): ancient bodies preserved in peat. *Risk:* sinking mud.
- [ ] **Shipwreck** (coastal): a drowned crew and salvageable metal. *Risk:* it floods with the tide.

**Wilds and shallow underground**

- [ ] **Plague pit** (surface or shallow): a huge pile of parts, all "pre-diseased." *Risk:* toxic gas that sickens ghouls.
- [ ] **Witch's hut** (forest or swamp): recipes, potions, a possible ally. *Risk:* she might have her own plans for you.
- [ ] **Smugglers' tunnels:** ready-made tunnels and hidden storage. *Risk:* smugglers who don't like visitors.
- [ ] **Collapsed mine** (new): trapped miners' bodies and metal ore. *Risk:* pockets of poison gas.

**Deep**

- [ ] **Sealed ossuary:** a vault of bones. *Risk:* breaking the seal wakes something.
- [ ] **Dead necromancer's lair:** his notes unlock new tech, and his heart can be claimed. *Risk:* his old minions are still loyal to him.
- [ ] **Soul geode:** crystallized souls, the only souls that don't require a death. *Risk:* mining it spikes Hunger.
- [ ] **Embalming spring:** a natural well of embalming fluid. *Risk:* floods if tapped carelessly.
- [ ] **Underground river** (new): fast transport for liquids and bodies. *Risk:* flooding when breached.

**The deep**

- [ ] **Buried titan:** enormous bones for golems. *Risk:* it may not be entirely dead.
- [ ] **Old god shrine:** void-magic unlocks. *Risk:* madness effects on nearby minions.
- [ ] **Demon outpost:** hellfire materials and demon souls. *Risk:* raiding it raises Hunger sharply.

### Simulated hazards

- **Liquids** (blood, embalming fluid, holy water) pool and flow, so a careless dig can flood a workshop.
- **Not all terrain is porous.** Soil soaks liquids up, but stone holds them, so a tunnel bored through a stone mountain works as a natural pipe.
- Proposed: fire spreading through wooden structures, and holy water seeping down from consecrated ground above.
- **Cave-ins:** cut. Noise (see Factory) punishes careless building instead.

## Core gameplay loop

Raid, process, raise, dig, repeat: each lap makes the army bigger and raises the heat from above or below.

(Diagram in the original doc: Raid → Process → Raise → Dig, with Suspicion feeding from raiding and processing, and Hunger from burning souls and digging deeper.)

Raiding and processing happen closest to the surface and feed Suspicion. Burning souls and digging deeper feed Hunger. The necrotic heart at the center of the lair sits between the two, draws both, and has to survive both.

## The necromancer

The necromancer never does physical labor. **His spells are his tools, one and the same:** digging, raising the dead, designating stockpiles and pulling in souls are all spells, picked like tools in any builder game and paid for in mana. His power comes from three things: mana, commands and souls.

### Mana

- **Mana is his stamina.** Every spell (boring tunnels, drawing bodies up through the earth, raising the dead) costs mana, which is what keeps early grave robbing slow.
- **Measured in souls.** The mana bar shows how many souls' worth of mana he can hold. Early on, one soul refills the entire bar.
- **Refilling, early game:** the necromancer clicks on the necrotic heart to refill his mana, spending souls stored there.
- **Refilling, later:** a tech-tree unlock refills his mana automatically whenever he's inside the heart's range. It still spends souls.
- **Siphon (spell):** draws mana straight out of a body, a part, or blood on the ground, but the material rapidly disintegrates into ash. It's a field refill at the cost of materials the factory could have used.
- **Blood is the best mana source.** Siphoning blood gives more mana than siphoning flesh or bone.
- Proposed: tech-tree upgrades, bought with souls, raise how many souls' worth of mana he can hold.

### Commands

He directs minions with commands instead of doing the work himself.

- **Dig:** he draws an area he wants dug out, and the ghouls assigned to digging clear it.
- **Tools matter:** ghouls need metal tools to dig stone or cut wood. Proposed: bare-handed ghouls can only dig soil.
- Proposed other commands: gather (collect bodies and parts in an area), harvest blood, haul, guard, attack, and return to the heart.

### Souls

- **Every minion costs at least one soul.** Even the lowest laborer needs one to be raised, and higher tiers need more.
- **All souls go into the heart.** Every harvested soul is deposited into the necrotic heart, which is where mana refills and minion raising draw from.
- **The heart's natural pull:** souls of anything that dies within the heart's range never despawn. They drift slowly toward the heart on their own.
- **Soul fragments:** woodland critters (rabbits, crows, rats, deer) and the lair's own pigs and chickens hold only a sliver of soul. Early on, the necromancer kills them for fragments, and enough fragments combine into one full soul orb. Exact amounts get tuned in playtesting.
- **Human souls:** a soul is collected whenever a human dies with the necromancer present. He doesn't have to land the killing blow, but he has to be there. Soul-collector minions (see Minions) are the exception: they gather souls on their own.
- **Fleeing ghosts:** some graveyards hold free souls that drift around like ghosts and flee when the necromancer approaches. They're quick and hard to catch by hand, which makes haunted graveyards a tempting but frustrating soul source early on.
- **Soul pull (later unlock):** a spell that spends mana to suck in every loose soul on screen, wherever it is. It turns haunted graveyards into a reliable harvest, and also scoops up critter fragments and the soul orbs dropped by fallen minions far from the heart.
- **What souls buy:** raising minions, refilling mana, tech-tree unlocks, and feeding elite minions and soul engines.
- Because souls are spent constantly, they have to be renewable: critters respawn, farm animals breed, settlements repopulate, and richer towns hold more valuable souls.
- Every soul collected draws attention from below. Proposed: fragments draw little or no Hunger, so the hidden start stays quiet.

## Harvesting and materials

Harvesting grows from the necromancer robbing graves by magic, to traps and ghoul labor, to a roaming army that gathers on command and feeds an industrial line.

### Harvesting phases

1. **Grave robber, by magic.** With a wave of his palm, the necromancer bores tunnels under the town cemetery and draws bodies up through the earth. Slow, risky, and limited by his mana.
2. **Traps and lures.** Early on, open fights are too dangerous, so the game includes components that work like traps. Spike traps are the starting point: the spikes are just spikes, and the necromancer digs the hole and places them by spell. Proposed: lures draw lone humans toward the traps at night (a lantern in the woods, a cry for help, a dropped coin purse), and later traps add snares and rigged bridges. If the necromancer is nearby, the soul is his.
3. **Ghoul labor.** Ghouls harvest by hand and can risk walking the surface at night.
4. **The gathering army.** The late game still revolves around an undead army that roams or follows commands to gather parts and bodies. Industry supports the army rather than replacing it, through triggers: for example, a body chute that a ghoul walks back to whenever it's carrying a body or a part. Proposed other triggers: a blood drop-off at the preservation vat, and a tool rack ghouls visit when a tool breaks.

### Materials

| Material | What it is | Source |
| --- | --- | --- |
| Parts | Flesh and bone together | Corpses |
| Gibs | Just flesh | Processed from parts |
| Bones | Just bone | Processed from parts |
| Blood | Liquid; the best source of mana | Fresh bodies only. Blood drains away on a timer after death; ghouls with a syringe and blood backpack draw it directly, which stops the timer, and carry it to a preservation vat |
| Wood | Building material | Chopped and hauled from towns by ghouls (needs metal tools) |
| Stone | Building material | Dug from terrain (needs metal tools); proposed: also torn from town walls and buildings |
| Metal | Tools and machines | Looted from towns (tools, armor, weapons) and smelted down |
| Soul | Raising every minion, mana, tech-tree currency, elite upkeep | Any human death the necromancer is present for; fragments from critters and farm animals; soul-collector minions |

Parts must be processed into gibs and bones before they can go into the stockpile. That makes the corpse grinder the first recipe the player learns.

## Factory and logistics

The factory is built into tunnels the player digs, within the radius of the necrotic heart (see Threats), so planning the space is as much a part of the puzzle as planning the production lines.

**Guiding principle:** building should feel straightforward. Getting conveyor belts, chutes and pipes working shouldn't be cumbersome; the physics simulation takes care of most of it.

### Building and moving things

- **Machines need room.** Every machine has a pixel footprint, so bigger machines mean digging bigger chambers.
- **Moving things sideways:** conveyor belts (early: ghouls carrying sacks; later: stitched-leather belts, then bone-chain lines).
- **Moving things up and down:** chutes and gravity drops going down, lifts and bone-cranes going up. Vertical logistics is where a side-view factory gets its own identity.
- **Liquids:** blood and embalming fluid flow through pipes and, if a pipe breaks, through the terrain. Stone doesn't soak liquids up, so a tunnel through stone can serve as a natural pipe.
- **Blood collection:** ghouls carry a syringe and a backpack that holds blood, and bring it back to a preservation vat.

### Storage

- **Stockpiles:** dig a hollow into the ground, then use the necromancer's designation spell to paint it for one resource: ossuaries for bones, flesh pits for gibs. Souls aren't stockpiled; they always go into the necrotic heart. Ghouls fill and empty them automatically.
- **Liquid storage:** liquids must be kept in metal or stone walled containers. Liquids stored in wood or anything else slowly evaporate.

### Staying hidden

The lair gives itself away four ways, and each one raises Suspicion:

- **Noise:** machines, laboring ghouls and shuffling minions all make noise (explosions most of all) that carries up toward the surface. Building deeper puts more earth between the noise and the people above, which rewards digging down. Proposed: stone muffles noise better than soil.
- **Smoke:** venting smoke to the surface.
- **Light:** glow that leaks out at night.
- **Stench:** the stench of death drifts upward, shown as a faint, browning-green scent wave.

Proposed upgrades to offset them: muffled machinery, smoke scrubbers, hidden vents, incense or embalming to mask the stench.

## Minions and production chains

Minions are both the workforce and the army. They aren't all just called "zombies": each class gets a title that's a little creepy and makes its tier obvious.

### Minion classes

Name ideas are proposals; the first in each row is the recommendation.

| Tier | Class | Name ideas | Made from | Role |
| --- | --- | --- | --- | --- |
| 1 | Laborer | **Ghoul**, Drudge, Thrall | Gibs, bones, 1 soul | All physical work: digging, hauling, harvesting. Needs food; decays outside the heart's range |
| 1 | Low melee | **Rotling**, Shambler, Fodder | Parts, stitching, 1 soul | Slow, cheap fighter that comes in bulk; decays outside the heart's range |
| 2 | Mid fighter | **Bonesworn**, Revenant, Gravewarden | Bones, metal, 1 soul | Armored or ranged fighter; decays outside the heart's range |
| 2 | Heavy | **Ossuary Golem**, Charnel Brute | Bones, stone, souls (proposed: 2) | Heavy labor and siege; decays outside the heart's range |
| 2 | Bomber | **Bloater**, Volunteer, Gasbag | Stitched body, explosive material, 1 soul | Suicide minion that breaks enemy defenses and formations (see Explosives) |
| 3 | Soul collector (brute) | **Harrower**, Abomination, Gorger | Gibs, bones, several souls | Stitched-together brute; collects souls from its kills without the necromancer present |
| 3 | Soul collector (scout) | **Reaper**, Wraith, Soulhound | Several souls, enchantment | Fast scout and assassin; collects souls on its own |
| 4 | Commander | **Lich** | Many souls | Commands an army group; leads raids on cities |

### Equipment

Risen minions can be equipped with weapons and tools, three options per class. Laborers start with none, until a later upgrade unlocks work tools. Low melee fighters get claw upgrades, and real weapons start at the mid-fighter tier. All options below are proposals. Proposed: equipment is crafted at an armory workshop and assigned per minion or per squad.

**Laborer (work tools, after a later upgrade)**

Laborers start bare-handed. A tech-tree upgrade later lets them equip work tools that help them dig faster or carry more.

| Equipment | What it does | Made from |
| --- | --- | --- |
| Drag sack | A bag dragged along the ground behind the ghoul, so it carries more per trip | Gibs (leather) |
| Shovel | Digs faster; an iron shovel can break through stone | Wood, metal |
| Blood kit | A syringe and backpack for drawing blood from fresh bodies | Metal, gibs |

**Low melee (claws)**

| Equipment | What it does | Made from |
| --- | --- | --- |
| Bone claws | A cheap first upgrade over bare hands | Bones |
| Iron talons | Hit harder and cut through light armor | Metal |
| Meat hooks | Hook an enemy and drag them out of formation | Metal, bones |

**Mid fighter (weapons)**

| Equipment | What it does | Made from |
| --- | --- | --- |
| Blade and shield | Looted town gear; solid all-round fighting | Metal, wood |
| Pike | Long reach; holds the line against knights and cavalry | Wood, metal |
| Bone bow | Ranged attacks with bone-shard arrows | Bones, gibs (sinew) |

**Heavy**

| Equipment | What it does | Made from |
| --- | --- | --- |
| Battering arm | Smashes gates and walls during sieges | Stone, metal |
| Tombstone shield | A wall of cover that minions behind it can advance under | Stone |
| Bomber hurler | Throws bombers over walls and into formations | Wood, bones, metal |

**Bomber**

| Equipment | What it does | Made from |
| --- | --- | --- |
| Sprinter legs | Run faster to reach the line before getting shot down | Bones, gibs |
| Bone plating | Soaks a few arrows on the way in | Bones |
| Shrapnel packing | A bigger, deadlier blast that scatters more parts | Bones, metal |

**Soul collector (brute)**

| Equipment | What it does | Made from |
| --- | --- | --- |
| Chain and hook | Pulls enemies in from a distance | Metal |
| Bone-crusher maul | Wide sweeping hits against crowds | Bones, stone |
| Soul cage | Holds the souls it collects, so they aren't lost if it dies | Metal, 1 soul |

**Soul collector (scout)**

| Equipment | What it does | Made from |
| --- | --- | --- |
| Scythe | Fast, lethal strikes; the classic reaper's tool | Metal, bones |
| Soul lantern | Pulls in nearby loose souls and fallen minions' soul orbs | Metal, 1 soul |
| Shade cloak | Harder to spot; raises less Suspicion when seen | Gibs, enchantment |

**Lich**

| Equipment | What it does | Made from |
| --- | --- | --- |
| Staff of command | Leads more minions over a wider area | Bones, several souls |
| Phylactery | Reforms at the heart instead of being destroyed | Metal, several souls |
| Grimoire | Casts spells from one magic school (fire, frost, toxic or void) | Several souls, enchantment |

not permanent. all of them are temporary at this level. IF they stay within the

### Life outside the heart

All low-level minions (tiers 1 and 2) are temporary, kept alive by the necrotic heart.

- **Inside the heart's range,** they last indefinitely, and if one dies there, the heart's natural pull draws its soul home.
- **Outside it,** they slowly lose health. Every surface raid, night harvest and battle away from base is on the clock. This includes heavies.
- **If one dies out there,** it drops the soul orb it was raised with. The necromancer has a short window to collect it (or catch it with soul pull); if he doesn't, the soul is gone for good.
- **Eating to heal:** higher-level minions can eat parts they come across in the world to refill their health. A toggle controls whether each minion is allowed to eat, since every part eaten is one the factory doesn't get.
- Proposed: the body of a fallen minion falls apart into parts that ghouls can haul home, and only part of the material can be recovered, so fresh bodies are always needed.
- Proposed: tech upgrades slow the decay (embalming, preservation rites), letting raids range further.

### Example chain: first fighter

1. Corpse → **corpse grinder** → gibs + bones
2. Gibs + bones → **stitching table** → stitched body
3. Stitched body + one soul orb + the necromancer's touch (costs mana) → **reanimation altar** → low melee fighter

Every step up the tiers costs more souls, so higher tiers depend on a steady supply.

### Ghoul tasks

Ghouls do all the physical work the necromancer won't. Proposed task list:

- **Earthworks:** dig the areas the necromancer marks with his dig command. Stone needs metal tools.
- **Hauling:** carry parts and materials, fill and empty stockpiles, load machines.
- **Harvesting:** collect corpses at night, strip battlefields after raids, draw blood with a syringe and backpack.
- **Town work:** chop wood (needs metal tools), tear down buildings for stone, loot tools and armor.
- **Production:** operate machines, run treadmills for power, stitch bodies.
- **Upkeep:** tend the pig and chicken farms, fight fires, bail out floods, repair belts.

All of this labor makes noise (see Factory: Staying hidden).

Each ghoul is assigned tasks with a simple priority list (like RimWorld's work tab), so the player sets who does what without micromanaging every step.

### Upkeep and food

Low-level minions cost little to keep but can't safely stray from the heart. Laborers and elites need ongoing upkeep, and better minions cost much more.

| Minion | Upkeep | If it isn't paid |
| --- | --- | --- |
| Laborer | Pig and chicken meat from the farms; gibs in a pinch | Complaints, then slowdowns, then a strike |
| Low melee and mid fighter | None inside the heart's range | Outside the range they slowly lose health; if they die there, the soul orb must be collected quickly or the soul is lost |
| Heavy | Proposed: none; repaired with bones | Proposed: slowly crumbles |
| Soul collector (brute) | Gibs, plus regular chances to kill living things | Turns on nearby minions when it isn't allowed to kill |
| Soul collector (scout) | Proposed: a trickle of souls | Proposed: fades away |
| Lich | Souls | Falls asleep until fed |

The player sets up farms of pigs and chickens to feed the ghouls. That gives the lair its own food chain, separate from the corpse supply. The animals also yield tiny soul fragments, like woodland critters.

### Quarters

In a Dungeon Keeper style, higher-level minions need their own space. A lich demands a private sanctum, and won't wake without one even when fed. Proposed: other elite minions have room needs too (an abomination pen, a wraith roost), and the quality of the room affects their mood and strength.

### Ghoul needs and unions

Ghouls have needs: rest (coffin bunks), food (farm meat or gib rations) and overtime limits. Neglect them and morale drops: first complaints (via the advisor's HR memos), then slowdowns, then a full strike with picket signs. Fixes include better rations, a break room, or a "motivational" visit from the necromancer, with consequences either way.

## Power

Proposed: power climbs through three eras, each stronger and each with a bigger downside, mirroring Satisfactory's biomass → coal → fuel → nuclear ladder.

| Era | Source | Upside | Downside |
| --- | --- | --- | --- |
| Early | Ghoul treadmills and hand cranks | Cheap, quiet, no fuel | Weak; tired ghouls complain and unionize faster |
| Mid | Bone-fire furnaces and blood boilers | Steady power from surplus bones and gibs | Smoke and light raise suspicion on the surface |
| Late | Soul engines | Huge output | Burns the scarcest resource; soul use draws demons from below |

This keeps both attention meters in play: dirty mid-game power gives you away above, and soul power gives you away below.

## Explosives

Explosions run through the whole pixel simulation, the way they do in Noita. A blast carves a crater out of the terrain, wrecks machines and buildings, starts fires, splashes liquids, and throws bodies apart, scattering parts that ghouls can collect afterward.

### Explosive materials (proposed)

| Material | Where it comes from | Blast |
| --- | --- | --- |
| Bloat gas | A byproduct of rotting gibs, collected by the factory | A sickly green toxic cloud that lingers (Green: Toxic) |
| Blasting powder | Looted from town armories, mines and alchemists | A fiery blast that sets things alight (Orange: Fire) |
| Frost charges | Made from snowy-biome materials | Freezes everything nearby solid (Blue: Frost) |
| Soul charges | Late game; built around a soul | A teal blast far stronger than anything else. Spends the soul, and draws Hunger |

### What explosives are for

- **Mining:** blast tunnels far faster than ghouls can dig them, at the cost of a huge noise spike.
- **Breaching:** crack town walls, city gates and eventually the holy fortress.
- **Demolition:** bring down buildings for stone.
- **Traps and defense:** rigged bridges, buried charges along the approach to the lair, and mines in tunnels that raiders come through.

### The risks

- **Explosions are the loudest thing in the game.** A blast underground raises Suspicion far more than any machine.
- **Chain reactions:** explosives stored carelessly can set each other off and take a whole wing of the factory with them. They need their own stockpile, away from fire and furnaces.
- **Enemies use them too.** Proposed: holy siege engineers bring fire bombs to cities and the fortress, and demons from below bring hellfire.

### Bombers

Suicide minions that the necromancer sends to the front lines to blow holes in enemy defenses and armies. Eyegor calls it the **Early Retirement Program**, and every bomber is, officially, a volunteer.

- **Built from:** a stitched body packed with an explosive material, plus one soul.
- **Variants (proposed):** one per explosive material. Bloat bombers gas a whole formation; powder bombers breach walls; frost bombers freeze a line in place; soul bombers flatten anything.
- **Detonation:** on contact with the enemy, on the necromancer's command, or when killed. A bomber shot down early explodes where it falls, which can be very bad news for your own lines.
- **Their souls:** every bomber spends a soul. When it detonates outside the heart's range, it drops its soul orb like any fallen minion, so the necromancer has to grab it (or use soul pull) or lose it. That keeps bombers a deliberate choice rather than something to spam.
- **Counterplay (proposed):** archers and holy priests try to pop bombers before they reach the line, so escorts and timing matter.
- **No upkeep:** they aren't meant to last.

## Threats

Enemies patrol on a regular cycle and grow stronger as the game goes on. Two attention meters decide how hard each side looks for you, and both are aimed at the necrotic heart.

### Forces from above

- Patrols come around periodically, starting with farmers and growing into soldiers and holy knights.
- Each biome's city has higher-level guards than its outlying towns.
- As the game progresses, these forces actively search for the necromancer. He may need to move his base from time to time (see The necrotic heart).

### Forces from below

- Souls draw demonic attention.
- Digging deep wakes old horrors, and past a certain depth a new tier of threat is unleashed permanently.

### The two meters

| Meter | Raised by | Lowered by | At high levels |
| --- | --- | --- | --- |
| Suspicion (above) | The heart's presence, missing bodies, daytime sightings, noise, smoke, light and stench from the lair, attacks on settlements | Time, staying hidden, eliminating witnesses | Inquisitor squads hunt for the lair; raids on the base |
| Hunger (below) | The heart's presence, collecting and burning souls, digging deeper | Offerings, sealing tunnels, warding | Demon incursions from below; old horrors break through |

### The necrotic heart

Every base is anchored by a necrotic heart that the necromancer places to mark its center. Within a set radius of it, the player can build structures and raise the dead, and low-level minions are sustained indefinitely (see Minions: Life outside the heart). The heart itself is what draws Suspicion and Hunger.

Relocation works both ways, as a choice the player weighs:

- **Stay and fight.** Defend the heart and the base around it. As the necromancer grows more powerful, he can simply stand up to the forces that come for him.
- **Pack up and flee.** Destroying the heart destroys everything linked to it. Rebuilding far away starts with less Suspicion, and the farther you move, the lower it starts.

A tech tree makes setting up a new base easier if the first one has to be abandoned.

Proposed ideas for that tech tree:

- **Heart upgrades:** a bigger radius, and later a second heart for outposts, which also extends how far minions can range without decaying.
- **Salvage rites:** recover a share of materials when you destroy a heart instead of losing everything.
- **Blueprints:** save a factory layout and have ghouls rebuild it at the new site.
- **Dampening wards:** slow how fast a heart gathers Suspicion and Hunger.
- **Decoy hearts:** a cheap fake heart that draws a patrol away from the real one.

## Progression and win condition

The player wins by conquering both the holy fortress on the surface and the demons' unholy citadel underground.

Along the way, the goal is to clear the people out of each settlement and raise a larger and larger army. Proposed shape of a run:

1. **Hidden start:** place the first heart, rob graves by magic, lure lone travelers into traps, hunt woodland critters for soul fragments, raise the first ghouls. Farmer patrols only.
2. **First conquest:** take the nearest small town, or farm it slowly and let it recover. Either way its population feeds the factory.
3. **Expansion:** take the second town; the city starts hunting you; dig deeper for rarer materials, or relocate to a new biome.
4. **Cities:** besiege each biome's city with higher-tier minions led by lich lieutenants.
5. **The two citadels:** storm the holy fortress above and the unholy citadel below, in either order.

Proposed: which citadel you take first shapes the ending. Taking heaven first lets hell grow stronger while you're busy, and vice versa. Milestones are announced by the advisor, who is thrilled with your performance review.

## Platform and tech

The game targets PC, sold on Steam, running on Steam Deck, with full controller support as well as keyboard and mouse.

What that means for design (proposed):

- **Controller-first building.** Placing machines and belts with a gamepad is the hard part of factory games. Plan a snap-to-grid build mode and radial menus from the start rather than bolting them on later.
- **Readable at 800p.** The Steam Deck screen is small, so the pixel scale, UI text and the glow-on-dark palette need testing at that size.
- **Performance.** A Noita-style falling-sand simulation is CPU-heavy, and the Deck is a modest machine. The simulation should only run in active chunks near the player and the factory.

### Engine

**Decision: Godot 4**, with the pixel simulation written as a native C++ module. First step before anything else: build a small test of just the falling-sand simulation and run it on a Steam Deck.

For reference, the options that were compared:

| Engine | Cost to sell on Steam | Fit for this game |
| --- | --- | --- |
| [Godot 4](https://forum.godotengine.org/tag/release/52) | Free and open source; no royalties | Strong 2D tools, GDScript or C#. Latest stable is 4.7 (June 2026). The pixel simulation would need native code for speed |
| [Unity 6](https://unity.com/products%20) | Free (Unity Personal) under $200K annual revenue; paid Pro above that | Mature, huge asset store, C#. Good controller support. Pixel sim is doable with its high-performance job system |
| [GameMaker](https://gamemaker.io/get) | Free to build; $99.99 one-time license to sell | Fastest for simple 2D prototypes, but the weakest fit for a heavy pixel simulation |
| [Unreal Engine](https://enginesdatabase.com/blog/state-of-unity-licensing-in-2026/) | Free until $1M gross revenue, then 5% royalties | Built for 3D; overkill and awkward for a 2D pixel game |
| Custom (C++ or Rust) | Free | Noita's route: full control of the simulation, but you also build UI, input, audio and saving yourself |

Why Godot: it costs nothing at any revenue level, it handles 2D well, and the one part that needs raw speed (the pixel simulation) can be written in C++ while everything else stays in a simpler scripting language. Unity is the solid second choice if a larger ecosystem of tutorials and assets matters more.

## Decisions log

| Topic | Decision |
| --- | --- |
| Name | *Unholy Assembly* |
| Advisor | Eyegor, an eye with black feathered wings, a clipboard and a quill |
| Biomes | Towns everywhere; cities in most biomes, rare in snowy and desert, none in the swamp (leech fishers instead) |
| Base | Built around the necrotic heart; both stay-and-fight and flee-and-rebuild |
| Attention meters | Keep both: Suspicion above, Hunger below |
| Spells | The necromancer's spells are his tools, one and the same, paid for in mana |
| Mana | Measured in souls' worth; refilled at the heart by spending souls (automatic in range after a tech unlock); Siphon draws mana from bodies, parts or blood, turning them to ash; blood is the best source |
| Soul collection | The necromancer must be present at a human death, but doesn't have to land the killing blow; soul-collector minions gather souls on their own |
| Soul storage | All souls are deposited into the heart; souls of anything dying in its range never despawn and drift toward it |
| Raising cost | Every minion costs at least one soul; critters and farm animals give small fragments that combine into a full soul orb |
| Ghost souls | Some graveyards hold fleeing ghost souls, caught easily only after unlocking the soul pull spell |
| Low-level minions | Sustained inside the heart's range, slowly lose health outside it (heavies included); if one dies out there, its soul orb must be collected quickly or the soul is lost |
| Healing | Higher-level minions can eat parts in the world to refill health, with a per-minion toggle |
| Equipment | Three options per class; laborers start bare-handed and unlock work tools (drag sack, shovel) later; low melee get claws; weapons start at mid fighter |
| Explosives | Explosions run through the whole pixel simulation; suicide bomber minions break enemy defenses and formations |
| Traps | Spike traps first: the necromancer digs the hole and places the spikes by spell |
| Cave-ins | Cut |
| Minion names | Each class gets a creepy, tier-revealing title instead of "zombie" |
| Hiding | Noise, smoke, light and stench all raise Suspicion |
| Sprite style | Large, detailed sprites; dark outlines; lanky proportions; flat colors with dynamic lighting |
| Engine | Godot 4 |

## Open questions

- [ ] **Minion names:** pick from the name ideas in the Minion classes table, including the new bomber class.
- [ ] **Equipment:** keep, cut or swap any of the three options per class.
- [ ] **Early stone and wood:** before laborers unlock tools, how does the player get stone and wood? Proposed: the necromancer's dig spell breaks stone, and wood comes from looting towns.
- [ ] **Explosive materials:** keep, cut or add to the four proposed (bloat gas, blasting powder, frost charges, soul charges).
- [ ] **Bombers:** one bomber class with a variant per explosive, or separate classes? Available early, or only after a tech unlock?
- [ ] **Soul pull:** how is it unlocked, and how much mana does it cost? Name ideas: *Grasp of the Grave*, *The Collection Notice* (Eyegor's preferred term), *Reaping Call*.
- [ ] **Mana capacity:** how does the bar grow beyond one soul's worth? Proposed: tech-tree upgrades.
- [ ] **Siphon and stored blood:** can the necromancer siphon blood from the preservation vat, or only blood on the ground?
- [ ] **Eating toggle:** which tiers count as "higher-level" for eating parts? Proposed: tier 2 and up.
- [ ] **Eyegor's voice:** how he writes and talks.
- [ ] **Spawn list:** check off the finds to keep in the Procedural spawns section.
- [ ] **Terrain scale:** how coarse the simulated terrain should be next to large sprites.
- [ ] **Pixel art tool:** a simple drawing artifact for sketching sprites.
- [ ] **Balance (playtesting):** fragment amounts from critters and farm animals, decay speed outside the heart, Siphon yields, blast sizes.

* [ ] **Balance (playtesting):** fragment amounts from critters and farm animals, decay speed outside the heart, Siphon yields, blast sizes.
