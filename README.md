# FS25 Remote Dispatcher

Remote Dispatcher is a Farming Simulator 25 script mod for remotely starting and stopping an already-prepared **AutoDrive** or **Courseplay** task without entering the vehicle.

The initial use case is cinematic/story-driven gameplay: prepare a vehicle normally, get out, position the player or camera, select the vehicle in Remote Dispatcher, then trigger its automation remotely.

## Current status

**v0.1.0.0 — proof of concept / single-player test build**

The first implementation deliberately keeps configuration inside AutoDrive and Courseplay. Remote Dispatcher only selects a compatible owned vehicle and tells its existing automation to start or stop.

## Intended workflow

1. Configure the vehicle's AutoDrive destination/mode or Courseplay job normally.
2. Leave the vehicle.
3. Press **Ctrl + Alt + D** to open Remote Dispatcher.
4. Use **Page Up / Page Down** to select an owned compatible vehicle.
5. If both integrations are present, press **Home** to switch between AD and CP.
6. Close the dispatcher if desired; the vehicle remains selected.
7. Position the player/camera for the shot.
8. Press **Ctrl + Alt + R** to remotely start/stop the selected automation.

All bindings can be remapped in FS25's Controls menu.

## v0.1 scope

- Single-player only.
- Root vehicles owned by the local farm only.
- Detect AutoDrive and Courseplay-capable vehicles.
- Start/stop the vehicle's already configured automation.
- Keep the selected vehicle after closing the overlay for one-key cinematic triggering.
- Prevent AD and CP from being started against each other on the same vehicle.

Out of scope for v0.1: remote route/course creation, destination selection, helper assignment, payroll and multi-stage orchestration.

## Testing

Use a test save initially and keep `log.txt` if something does not behave as expected.

Suggested first test:

1. Configure one tractor with an AutoDrive **Drive To** destination.
2. Exit the tractor.
3. Select it in Remote Dispatcher and trigger the remote action.
4. Repeat with a simple Courseplay fieldwork job.

## Longer-term direction

Once the remote start/stop layer is reliable, this can become the dispatch front-end for more complete worker orchestration: Remote Dispatcher + AutoDrive + Courseplay, with optional integration into HelperProfiles, HelperPayroll and AvatarSwitcher.