# FS25 Remote Dispatcher

Remote Dispatcher is a Farming Simulator 25 script mod for remotely starting and stopping an already-prepared **AutoDrive** or **Courseplay** task without entering the vehicle.

## Current status

**v0.1.0.4 — alpha / single-player test build**

The target vehicle is persistent: once selected, player distance does not affect remote dispatch. Proximity is used only for the initial target when no selection has yet been made.

## Controls

- **Ctrl + Alt + D** — open/close Remote Dispatcher.
- **- / =** — previous/next compatible vehicle while the Dispatcher is open.
- **\** — switch AutoDrive/Courseplay for the selected vehicle.
- **Enter** — start/stop the selected vehicle while the Dispatcher is open.
- **Ctrl + Alt + R** — start/stop the retained target from anywhere, including with the Dispatcher closed.

All bindings are normal FS25 actions and can be remapped in Controls.

## v0.1.0.4 changes

- Persistent remote selection independent of player distance.
- Replaced arrow navigation with dedicated `-`, `=`, `\` and Enter actions so Dispatcher controls no longer move the player/camera.
- Fixed-column overlay for vehicle, automation, state, target/course and distance.
- Dispatcher visibility follows the main FS25 HUD.
- Ctrl+Alt+R remains available while the panel/HUD is hidden for cinematic triggering.
- Remotely started AD/CP vehicles are explicitly woken with `raiseActive()` and held active for five seconds so their automation update loop can begin without player proximity.
- Existing AutoDrive discovery/start diagnostics retained.

## Workflow

1. Prepare the vehicle's AutoDrive route/mode or Courseplay job normally.
2. Open Remote Dispatcher and select the vehicle once.
3. Move anywhere required for the camera shot.
4. Close the Dispatcher or hide the main HUD if desired.
5. Press **Ctrl + Alt + R** to start/stop the retained vehicle.

Single-player only for the current prototype.
