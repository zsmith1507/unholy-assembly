# Eyegor's voice

Eyegor is the company's **Director of Undying Resources**: one floating eye, two black feathered wings, a clipboard and a quill. He reads everything off the clipboard. He adores his employer, loves his job, and describes atrocities in the register of an HR onboarding video.

This guide is how he writes. All his words live in `lines.gd`; change them there.

## The five rules

1. **Relentlessly positive.** Every event is good news, an opportunity, or a "learning experience". He never sneers at the player; his dry wit is aimed at the forces of good and at the grim business itself. Bad news gets the driest, calmest delivery in the game ("That's a setback. But it *is* data.").
2. **Corporate euphemism for the horror.** He never says the grim word when a cheerful one will do, and the joke is the gap between the two:
   - corpses: *pre-owned personnel*, *legacy staff*, *donors*
   - dying: *a career transition*, *leaving the workforce (temporarily)*
   - grave robbing: *talent acquisition*, *community recruitment*
   - grinding: *restructuring*, *reorganising into component talent*
   - villagers: *prospective colleagues*; farmers with pitchforks: *community stakeholders*
   - Suspicion: *public interest*, *brand awareness*; Hunger: *interest from our partners downstairs*
3. **The instruction is never hidden by the joke.** Tutorial lines say plainly what to do, and usually say it first or last in its own sentence: "Place your Necrotic Heart underground." The flavour goes around it.
4. **Short.** Announcements 2 to 6 words. Commentary one to three sentences, about 140 characters at most, so a line fits his panel at 640×360 without scrolling. Memos may run a little longer. If a line can lose a word, it loses it.
5. **He calls the player "Master".** It's the hunchbacked-assistant heritage, said in a cheerful office voice. ("Wonderful work, Master!")

## What we took from Dungeon Keeper (Zach's steer)

Zach pointed us at *Dungeon Keeper* and its narrator, the Mentor. Eyegor keeps his cheerful office manner, but he borrows the Mentor's craft. We take the technique, never his lines.

1. **Economy. Most of what he says is an announcement.** The Mentor's best-known lines are four or five words in a flat, grave voice: a status report, not a joke. Eyegor now has two registers:
   - **Announcements** (`ann_*` keys): 2 to 6 words, a full stop, no exclamation mark, no "Master". They fire often and must never get tiring: "A ghoul is hungry." "The grinder is idle." "Suspicion is rising."
   - **Commentary**: the one-to-three-sentence lines with the corporate euphemism. These are rarer, so they stay funny.
2. **Timing: say it straight, then the turn.** The joke lands in the last two or three words, after a full stop, never in the middle of a clause. Set up plainly, beat, payoff. "The patrol has gone home. Most of it."
3. **Relish.** The Mentor is delighted by your villainy and treats evil as the natural, sensible order of things. Eyegor is never squeamish: the euphemisms are not him hiding from the horror, they are him enjoying it. He compliments cruelty the way a manager compliments a tidy spreadsheet.
4. **Good is the bore, not the threat.** Heroes, priests and farmers with pitchforks are spoken of with weary, gentle contempt: earnest, tiresome, a bit smelly. We never fear them out loud; we find them inconvenient.
5. **Understatement over volume.** A disaster gets the calmest line in the game. The bigger the catastrophe, the fewer and drier the words. ("The Heart has been destroyed. That's a setback.")
6. **Deadpan tips.** Like the Mentor's hints, Eyegor's tips state a cruel, useful fact plainly and let the player enjoy it. ("Ghouls dig faster when they're hungry. They're also more likely to eat each other.")

Voice actor note, for later: a deep, slow, warm baritone reading a cheerful script. The contrast is the joke.

## Moods

| Mood | When | Sound |
| --- | --- | --- |
| `announce` | Status reports (`ann_*`) | Flat, grave, full stop. One line in the corner, no portrait chatter |
| `chipper` | Default: tutorials, commentary | Warm and pleased with you; one exclamation mark at most |
| `proud` | Milestones, firsts | Gushing; "performance review" talk |
| `concerned` | Suspicion or Hunger rising, losses | Still positive, visibly strained; "let's circle back" |
| `memo` | Ghoul complaints and notices | A formal HR notice pinned to the clipboard, signed by him |

## Memos

Memos are pinned to the clipboard on cream paper. Format: a `RE:` subject line, a body in calm HR prose, then the sign-off "Eyegor, Director of Undying Resources". The ghouls' complaints are relayed with complete sincerity ("The ghouls have asked, politely, for somewhere to sit that isn't another ghoul.").

## Item descriptions

Deadpan catalogue style, like a second-hand shop that doesn't ask questions: a name with a condition grade, then one dry sentence.
"Left Arm, Slightly Used. Previous owner no longer requires it."

## The mission statement

**"Bringing Eternal Life to a Village Near You, Since 1197."** It appears on the title screen, loading screens and every milestone banner. He quotes it with feeling.

## Boundaries

- Children may be mentioned as an abstract part of a town's population, never as anyone harmed. No jokes at their expense.
- Gore is described clinically or euphemistically, never lingered on. The horror is in what he *doesn't* say.
- No real-world slurs, no punching at real groups. The targets are corporate culture, the pompous forces of "good", and the necromancer's own grim industry.
