# FS25 Remote Dispatcher

Remote Dispatcher is a Farming Simulator 25 script mod for remotely starting and stopping an already-prepared **AutoDrive** or **Courseplay** task without entering the vehicle.

## Current status

**v0.2.0.1 — alpha / single-player test build**

The GUI is deliberately a compact **cinematic setup panel**, not the place where the vehicle is started. Selecting a vehicle retains it as the remote target. Configure its automation/worker, close the panel, position the camera, and trigger the vehicle from the world.

## Controls

- **Ctrl + Alt + D** — open Remote Dispatcher.
- **Ctrl + Alt + R** — start/stop the retained target remotely after the Dispatcher is closed.
- In the Dispatcher: **X** cycles AutoDrive/Courseplay where both are available.
- In the Dispatcher: **C** cycles AUTO and enabled HelperProfiles workers.

Normal list navigation is handled by GIANTS GUI focus, so arrows/D-pad do not move the player or camera while the dialog is open.

## Compact Dispatcher GUI

The single vehicle list shows:

- vehicle name;
- AutoDrive/Courseplay capability;
- ready/active state;
- assigned worker;
- current AD destination or CP course.

Selecting a row immediately makes that vehicle the retained cinematic target. The only configuration buttons are **Automation** and **Worker**. There is intentionally no Dispatch button.

The intended workflow is:

1. Prepare the AD destination/mode or CP job normally.
2. Open Remote Dispatcher.
3. Select the vehicle.
4. Optionally choose AD/CP and assign AUTO or a named HelperProfiles worker.
5. Close Remote Dispatcher.
6. Position the player/camera for the shot.
7. Press **Ctrl + Alt + R**.

## HelperProfiles integration

`AUTO` keeps normal HelperProfiles/game helper selection. A named assignment uses HelperProfiles API v7 `beginPreferredHire()` / `endPreferredHire()` around the synchronous AutoDrive/Courseplay start. The scoped request is fail-closed: if the assigned worker is active, off roster, or unavailable, dispatch fails rather than silently substituting another worker.

The normal HelperProfiles selected worker is not changed. Worker assignments are runtime/session state in this test build.

## Remote vehicle activation

The v0.1.0.4 wake logic is retained. Remote Dispatcher calls `raiseActive()` before/after starting automation and briefly keeps the vehicle active so distant AutoDrive/Courseplay tasks begin without requiring player proximity.

Single-player only for the current prototype.
