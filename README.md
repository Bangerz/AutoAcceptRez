# Auto Accept Rez

World of Warcraft **retail** addon (The War Within / Midnight, interface `110007` and `120000`–`120002`). When another player resurrects you, it waits **5 seconds**, then accepts the resurrection automatically **only** when:

- You are **not in a boss encounter** (`C_InstanceEncounter.IsEncounterInProgress()` / `IsEncounterInProgress()`).
- The resurrecting player is **out of combat**, as reported by `UnitAffectingCombat` on their party or raid unit.

If you stand up early (accept manually, release spirit, etc.), any pending timer is cancelled.

While the timer is running, a line of text appears just below center screen (near the default resurrect dialog), counting down: **Auto Accept Rez: accepting in 5...** through **1...**. It hides when the timer ends or is cancelled.

## Install

Copy the `AutoAcceptRez` folder into:

`World of Warcraft\_retail_\Interface\AddOns\`

Enable **Auto Accept Rez** in the AddOns list and `/reload`.

## Limitation

`UnitAffectingCombat` only works for units in your **party or raid**. If someone not in your group resurrects you, the addon cannot verify their combat state and will **not** auto-accept.

## License

See [LICENSE](LICENSE) in this repository (CC0-1.0).
