# FS25 Remote Dispatcher

Remote Dispatcher remotely starts/stops prepared AutoDrive or Courseplay jobs without entering the vehicle.

## v0.2.2.0 test architecture

Remote Dispatcher has two deliberately separate interfaces:

- **Management GUI** — configure each vehicle's automation provider and preferred HelperProfiles worker.
- **In-game target selector** — lightweight HUD for choosing the retained cinematic target.

The management screen never starts a job and browsing it does not change the live target. Remote execution always comes from the vehicle selected in the in-game selector.

## Controls

- **Ctrl + Alt + D** — toggle the in-game target selector.
- **Ctrl + Alt + M** — open Remote Dispatcher Management.
- **=** — next vehicle while the target selector is visible.
- **-** — previous vehicle while the target selector is visible.
- **Ctrl + Alt + R** — remotely start/stop the retained target.
- In Management: **X** — cycle AD/CP for the highlighted vehicle.
- In Management: **C** — assign the highlighted worker to the highlighted vehicle.

The selector follows the main HUD visibility, so hiding the FS25 HUD also hides Remote Dispatcher while Ctrl+Alt+R remains available.

## Management GUI

The Management screen uses separate vehicle and worker panes. Select a vehicle on the left, select `AUTO` or an enabled HelperProfiles worker on the right, then use **Assign Worker**. The current assignment is shown in the vehicle table.

Each vehicle remembers its own automation choice (AD/CP) and HelperProfiles worker assignment for the session. Named worker dispatch requires HelperProfiles API v7. `AUTO` preserves normal HelperProfiles/game helper selection.

## Active selector

The live selector uses a compact autosizing table inspired by HelperProfiles. It measures the displayed vehicle, automation, worker, and state values rather than reserving a large fixed panel. The selected target is marked and the current AD route/CP course is shown below the table.

## Cinematic workflow

1. Configure AD/CP normally on the vehicle.
2. Use **Ctrl+Alt+M** if automation or worker assignment needs changing.
3. Close Management.
4. Toggle the selector with **Ctrl+Alt+D**.
5. Cycle to the required vehicle with **- / =**.
6. Hide the selector/HUD if desired and position the camera.
7. Press **Ctrl+Alt+R**.

The distant-vehicle wake logic introduced in v0.1.0.4 remains active.
