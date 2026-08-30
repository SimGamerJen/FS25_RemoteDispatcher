# FS25 Remote Dispatcher

Remote Dispatcher remotely starts/stops prepared AutoDrive or Courseplay jobs without entering the vehicle.

## v0.2.1.0 test architecture

Remote Dispatcher now has two separate interfaces:

- **Management GUI**: per-vehicle automation and preferred HelperProfiles worker assignment.
- **In-game target selector**: lightweight HUD used while staging cinematics to select the retained remote target.

The management screen never starts a job. Remote execution always comes from the retained selector target.

## Controls

- **Ctrl + Alt + D** — toggle the in-game target selector.
- **Ctrl + Alt + M** — open Remote Dispatcher Management.
- **=** — next vehicle while the target selector is visible.
- **-** — previous vehicle while the target selector is visible.
- **Ctrl + Alt + R** — remotely start/stop the retained target.

The selector follows the main HUD visibility, so hiding the FS25 HUD also hides Remote Dispatcher while Ctrl+Alt+R remains available.

## Management

Each vehicle remembers its own automation choice (AD/CP) and HelperProfiles worker assignment. Named worker dispatch requires HelperProfiles API v7. `AUTO` preserves normal HelperProfiles/game helper selection.

## Cinematic workflow

1. Configure AD/CP normally on the vehicle.
2. Use **Ctrl+Alt+M** if automation or worker assignment needs changing.
3. Close Management.
4. Toggle the selector with **Ctrl+Alt+D**.
5. Cycle to the required vehicle with **- / =**.
6. Hide the selector/HUD if desired and position the camera.
7. Press **Ctrl+Alt+R**.

The distant-vehicle wake logic from v0.1.0.4 remains active.
