# FS25 Remote Dispatcher

Remote Dispatcher is a single-player Farming Simulator 25 script mod for remotely starting and stopping an already-prepared **AutoDrive** or **Courseplay** task without entering the vehicle.

## Current status

**v0.3.0.0 — early alpha release candidate**

The core cinematic workflow has been proven in-game: configure a vehicle, choose it from a lightweight HUD selector, move the player/camera away from the vehicle, then remotely start it without entering the cab.

## Interfaces

Remote Dispatcher deliberately separates configuration from live cinematic targeting:

- **Management GUI** — configure each vehicle's AutoDrive/Courseplay choice and optional HelperProfiles worker assignment.
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

HelperProfiles is optional. Without it, Remote Dispatcher uses `AUTO` and the normal game/automation helper-selection flow.

Named worker assignment requires a compatible **HelperProfiles API v7** build. A named assignment is scoped to the dispatch request and is fail-closed: if the assigned worker is unavailable, Remote Dispatcher refuses the start instead of silently substituting another worker.

For the alpha-candidate test cycle, use the API v7 HelperProfiles test build supplied with the test package. Promoting API v7 into a formal HelperProfiles release is tracked as an alpha release-gate item.

## Per-save persistence

Version 0.3.0.0 persists configuration under:

`modSettings/FS25_RemoteDispatcher/saves/savegameX/dispatcher.xml`

Persistence is keyed to the vehicle's FS25 `uniqueId`, so it does not depend on alphabetical ordering, model name, or player proximity. The following survive a save reload:

- AD/CP choice per vehicle;
- HelperProfiles worker assignment per vehicle;
- retained cinematic target.

Records for vehicles no longer present in the save are harmless and ignored.

## Diagnostics

Run this in the developer console when reporting an alpha issue:

`rdStatus`

It prints the detected vehicles, retained target, AD/CP provider, worker assignment, HelperProfiles API state, and persistence file path to `log.txt`.

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

- Farming Simulator 25.
- AutoDrive and/or Courseplay for the corresponding automation functions.
- HelperProfiles API v7 only if named worker assignment is wanted.
- Single-player only in the current alpha.

See `docs/ALPHA_RELEASE_CHECKLIST.md` for the release gate and known beta follow-up work.
