# FS25 Remote Dispatcher

Remote Dispatcher is a Farming Simulator 25 script mod for remotely starting and stopping an already-prepared **AutoDrive** or **Courseplay** task without entering the vehicle.

The initial use case is cinematic/story-driven gameplay: prepare a vehicle normally, get out, position the player or camera, select the vehicle in Remote Dispatcher, then trigger its automation remotely.

## Current status

**v0.1.0.2 — proof of concept / single-player test build**

The implementation deliberately keeps route/job configuration inside AutoDrive and Courseplay. Remote Dispatcher selects a compatible owned vehicle and tells its existing automation to start or stop.

## Controls

- **Ctrl + Alt + D** — open/close Remote Dispatcher.
- **Up / Down** — select previous/next compatible vehicle while the Dispatcher is open.
- **Left / Right** — switch between AutoDrive and Courseplay where both are available.
- **Enter** — start/stop the highlighted vehicle while the Dispatcher is open.
- **Ctrl + Alt + R** — start/stop the retained target, including with the Dispatcher closed.

All bindings can be remapped in FS25's Controls menu.

## v0.1.0.2 changes

- Replaced Page Up/Page Down/Home navigation with Up/Down/Left/Right.
- Added Enter as an open-HUD start/stop action.
- On the first Dispatcher open, selects the compatible vehicle nearest to the player instead of alphabetical row 1.
- Added distance to each vehicle row and a stronger `TARGET:` summary.
- AutoDrive destination display now prefers AutoDrive's own selected-marker-name API.
- Retained v0.1.0.1 discovery fixes and diagnostics.
- Added additional AD start diagnostics.
- Preserved normal AutoDrive helper acquisition, allowing HelperProfiles `preferSelected` mode to supply the currently selected free worker.

## Intended workflow

1. Configure the vehicle's AutoDrive destination/mode or Courseplay job normally.
2. Leave the vehicle.
3. Open Remote Dispatcher.
4. Confirm the `TARGET:` line shows the intended vehicle.
5. Press **Enter** to test immediately, or close the Dispatcher while retaining the target.
6. Position the player/camera.
7. Press **Ctrl + Alt + R** to trigger the retained target remotely.

## Testing note

If AutoDrive reports ACTIVE but the intended target still does not move, keep `log.txt`. v0.1.0.2 logs the target vehicle, AD destination IDs, active state, and helper index around the remote start request.

Single-player only for the current prototype.
