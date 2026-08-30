# FS25 Remote Dispatcher

Remote Dispatcher is a Farming Simulator 25 script mod for remotely starting and stopping an already-prepared **AutoDrive** or **Courseplay** task without entering the vehicle.

## Current status

**v0.1.0.3 — alpha / single-player test build**

The target vehicle is persistent: once selected, player distance does not affect remote dispatch. Proximity is used only for the initial target when no selection has yet been made.

## Controls

- **Ctrl + Alt + D** — open/close Remote Dispatcher.
- While the Dispatcher is visible: **Up / Down** selects a vehicle.
- While visible: **Left / Right** selects AutoDrive or Courseplay where both are available.
- While visible: **Enter** starts/stops the selected automation.
- **Ctrl + Alt + R** — start/stop the retained target remotely, including with the Dispatcher closed or the normal HUD hidden.

The arrow and Enter keys are raw Dispatcher-only inputs; they are no longer registered as normal gameplay actions.

## v0.1.0.3 changes

- Persistent remote selection independent of player distance.
- Raw Up/Down/Left/Right/Enter navigation to avoid action-context conflicts.
- Fixed-column overlay for vehicle, automation, state, target/course and distance.
- Dispatcher visibility now follows the main FS25 HUD.
- Ctrl+Alt+R remains available while the panel/HUD is hidden for cinematic triggering.
- Existing AutoDrive discovery/start diagnostics retained.

## Workflow

1. Prepare the vehicle's AutoDrive route/mode or Courseplay job normally.
2. Open Remote Dispatcher and select the vehicle once.
3. Move anywhere required for the camera shot.
4. Close the Dispatcher or hide the main HUD if desired.
5. Press **Ctrl + Alt + R** to start/stop the retained vehicle.

Single-player only for the current prototype.
