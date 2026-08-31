# FS25 Remote Dispatcher

Remote Dispatcher is a single-player Farming Simulator 25 script mod for remotely starting and stopping an already-prepared **AutoDrive** or **Courseplay** task without entering the target vehicle.

## Current status

**v0.3.0.1 — alpha.2 test candidate**

The first public alpha exposed an input-context limitation: Remote Dispatcher controls were registered only while the player was on foot. Version 0.3.0.1 adds the same live dispatcher actions to FS25's vehicle input context so another prepared worker can be selected and dispatched while the player is driving a different vehicle.

> **Alpha dependency:** Remote Dispatcher is released and tested against **HelperProfiles 2.1.1.0**. Install HelperProfiles 2.1.1.0 alongside this alpha before reporting Remote Dispatcher issues.

HelperProfiles 2.1.1.0: https://github.com/SimGamerJen/FS25_HelperProfiles/releases/tag/2.1.1.0

## Interfaces

Remote Dispatcher separates configuration from live targeting:

- **Management GUI** — configure each vehicle's AutoDrive/Courseplay choice and HelperProfiles worker assignment.
- **In-game target selector** — compact HUD used to choose the retained vehicle that `Ctrl + Alt + R` will control.

Browsing the Management GUI does **not** change the live target.

## Controls

The live controls are available both **on foot and while controlling another vehicle**:

- **Ctrl + Alt + D** — toggle the in-game target selector.
- **Ctrl + Alt + J** — open Remote Dispatcher Management.
- **=** — next target while the selector is visible.
- **-** — previous target while the selector is visible.
- **Ctrl + Alt + R** — remotely start/stop the retained target.
- Management: **X** — change AutoDrive/Courseplay for the highlighted vehicle.
- Management: **C** — assign the highlighted worker to the highlighted vehicle.

`Ctrl + Alt + J` replaces the original `Ctrl + Alt + M` Management shortcut because current AutoDrive releases use `Ctrl + Alt + M` for notification history.

All actions are normal FS25 input actions and can be remapped.

## HelperProfiles integration

The public alpha is supported with **HelperProfiles 2.1.1.0**.

HelperProfiles 2.1.1.0 publishes **Integration API v7**, which Remote Dispatcher uses for named-worker dispatch. A named assignment is scoped to the individual dispatch request and is fail-closed: if the assigned worker is missing, OFF roster or already active, Remote Dispatcher refuses the start instead of silently substituting another worker.

The scoped request does not alter the worker selected in the normal HelperProfiles overlay or change the user's HelperProfiles hiring mode.

Although the code retains an `AUTO` fallback path, the supported configuration for this public alpha includes HelperProfiles 2.1.1.0 so testers exercise the same integration contract used during release validation.

## Per-save persistence

Remote Dispatcher persists configuration under:

`modSettings/FS25_RemoteDispatcher/saves/savegameX/dispatcher.xml`

Persistence is keyed to the vehicle's FS25 `uniqueId`. The following survive a save reload:

- AD/CP choice per vehicle;
- HelperProfiles worker assignment per vehicle;
- retained remote target.

Records for vehicles no longer present in the save are harmless and ignored.

## Diagnostics and alpha feedback

Run this in the developer console when reporting an alpha issue:

`rdStatus`

It prints the detected vehicles, retained target, AD/CP provider, worker assignment, HelperProfiles API state, persistence file path, and whether the vehicle input hook is installed to `log.txt`.

For a useful issue report, include `log.txt`, the `rdStatus` output, the vehicle involved, whether the task was AutoDrive or Courseplay, and whether the worker assignment was AUTO or named.

## Typical workflow

1. Prepare the target vehicle's AD destination/mode or CP job normally.
2. Use **Ctrl + Alt + J** if its automation or worker assignment needs changing.
3. Toggle the live selector with **Ctrl + Alt + D**.
4. Use **- / =** to choose the target vehicle.
5. Continue driving, move away, or position the camera as required.
6. Press **Ctrl + Alt + R** to start or stop the retained remote target.

The distant-vehicle wake logic keeps the remotely dispatched vehicle active long enough for AD/CP to begin without player proximity.

## Dependencies and scope

- Farming Simulator 25.
- **HelperProfiles 2.1.1.0** — required supported companion for this alpha.
- AutoDrive and/or Courseplay for the corresponding automation functions.
- Single-player only.

### Known alpha limitations

- Remote Dispatcher does not configure AutoDrive destinations or build Courseplay jobs; tasks must already be prepared.
- AutoDrive/Courseplay compatibility is based on their current runtime interfaces and may require adapter changes when those mods update.
- The initial alpha UI is English only.
- Input/gamepad coverage is not yet considered beta-complete.
- Testing across maps and a broad range of vehicle configurations is still limited.
- Stale persistence records for sold vehicles are currently ignored rather than automatically pruned.

See `docs/ALPHA_RELEASE_CHECKLIST.md` for the completed early-alpha gate and the remaining beta follow-up work.
