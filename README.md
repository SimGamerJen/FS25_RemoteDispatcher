# FS25 Remote Dispatcher

Remote Dispatcher is a single-player Farming Simulator 25 script mod for remotely starting and stopping an already-prepared **AutoDrive** or **Courseplay** task without entering the vehicle.

## Current status

**v0.3.0.0 — early public alpha**

> **Alpha dependency:** Remote Dispatcher 0.3.0.0-alpha.1 is released and tested against **HelperProfiles 2.1.1.0**. Install HelperProfiles 2.1.1.0 alongside this alpha before reporting Remote Dispatcher issues.

HelperProfiles 2.1.1.0: https://github.com/SimGamerJen/FS25_HelperProfiles/releases/tag/2.1.1.0

The core cinematic workflow has been proven in-game: configure a vehicle, choose it from a lightweight HUD selector, move the player/camera away from the vehicle, then remotely start it without entering the cab.

This is an **early alpha** intended to put the feature into real users' hands and gather compatibility feedback. Back up important savegames and expect rough edges outside the tested workflow.

## Interfaces

Remote Dispatcher deliberately separates configuration from live cinematic targeting:

- **Management GUI** — configure each vehicle's AutoDrive/Courseplay choice and HelperProfiles worker assignment.
- **In-game target selector** — compact HUD used to choose the retained vehicle that `Ctrl + Alt + R` will control.

Browsing the Management GUI does **not** change the live target.

## Controls

- **Ctrl + Alt + D** — toggle the in-game target selector.
- **Ctrl + Alt + M** — open Remote Dispatcher Management.
- **=** — next target while the selector is visible.
- **-** — previous target while the selector is visible.
- **Ctrl + Alt + R** — remotely start/stop the retained target.
- Management: **X** — change AutoDrive/Courseplay for the highlighted vehicle.
- Management: **C** — assign the highlighted worker to the highlighted vehicle.

All actions are normal FS25 input actions and can be remapped.

## HelperProfiles integration

The public 0.3.0.0 early alpha is supported with **HelperProfiles 2.1.1.0**.

HelperProfiles 2.1.1.0 publishes **Integration API v7**, which Remote Dispatcher uses for named-worker dispatch. A named assignment is scoped to the individual dispatch request and is fail-closed: if the assigned worker is missing, OFF roster or already active, Remote Dispatcher refuses the start instead of silently substituting another worker.

The scoped request does not alter the worker selected in the normal HelperProfiles overlay or change the user's HelperProfiles hiring mode.

Although the current code retains an `AUTO` fallback path, the supported configuration for this public alpha includes HelperProfiles 2.1.1.0 so that testers are exercising the same integration contract used during release validation.

## Per-save persistence

Version 0.3.0.0 persists configuration under:

`modSettings/FS25_RemoteDispatcher/saves/savegameX/dispatcher.xml`

Persistence is keyed to the vehicle's FS25 `uniqueId`, so it does not depend on alphabetical ordering, model name, or player proximity. The following survive a save reload:

- AD/CP choice per vehicle;
- HelperProfiles worker assignment per vehicle;
- retained cinematic target.

Records for vehicles no longer present in the save are harmless and ignored.

## Diagnostics and alpha feedback

Run this in the developer console when reporting an alpha issue:

`rdStatus`

It prints the detected vehicles, retained target, AD/CP provider, worker assignment, HelperProfiles API state, and persistence file path to `log.txt`.

For a useful issue report, include:

- `log.txt` from the affected session;
- the output surrounding `rdStatus`;
- whether the task was AutoDrive or Courseplay;
- the vehicle/mod involved;
- whether the assigned HelperProfiles worker was AUTO or a named worker;
- whether the problem still occurs after a full FS25 restart.

## Cinematic workflow

1. Prepare the vehicle's AD destination/mode or CP job normally.
2. Use **Ctrl + Alt + M** if its automation or worker assignment needs changing.
3. Close Management.
4. Toggle the selector with **Ctrl + Alt + D**.
5. Use **- / =** to choose the vehicle.
6. Hide the selector/HUD if desired and position the camera.
7. Press **Ctrl + Alt + R**.

The distant-vehicle wake logic keeps the remotely dispatched vehicle active long enough for AD/CP to begin without player proximity.

## Dependencies and scope

For the 0.3.0.0-alpha.1 public alpha:

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
