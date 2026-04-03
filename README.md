# Auto Accept Rez

World of Warcraft **retail** addon (The War Within / Midnight, interface `110007` and `120000`–`120003`). A pending resurrection is detected via **`RESURRECT_REQUEST`** and **`INCOMING_RESURRECT_CHANGED`** / **`UnitHasIncomingResurrection("player")`** so it still runs if only one of those fires on your patch. When a rez is pending, it waits **5 seconds**, then accepts automatically **only** when:

- You are **not in a boss encounter** (`C_InstanceEncounter.IsEncounterInProgress()` / `IsEncounterInProgress()`).
- The resurrecting player is **out of combat**, as reported by `UnitAffectingCombat` on their party or raid unit.

If you stand up early (accept manually, release spirit, etc.), any pending timer is cancelled.

While the timer is running, a feedback bar (same look as **Auto Accept Summon**) sits just under the resurrect **StaticPopup** when it is visible, otherwise centered; it counts down **5…1**. It hides when the timer ends or is cancelled.

## Install

Copy the `AutoAcceptRez` folder into:

`World of Warcraft\_retail_\Interface\AddOns\`

Enable **Auto Accept Rez** in the AddOns list and `/reload`.

## Limitation

`UnitAffectingCombat` only works for units in your **party or raid**. If someone not in your group resurrects you, the addon cannot verify their combat state and will **not** auto-accept (you may still see the countdown).

This build does not log debug lines to chat. If the addon seems inert, enable **Display Lua Errors** (Interface options → Help, or `/console scriptErrors 1`) and `/reload` to catch load-time Lua errors (from any addon).

## License

See [LICENSE](LICENSE) in this repository (CC0-1.0).
