# FS25 Remote Dispatcher

Remote Dispatcher is a Farming Simulator 25 script mod for remotely starting and stopping an already-prepared **AutoDrive** or **Courseplay** task without entering the vehicle.

## Current status

**v0.2.0.0 — alpha / single-player test build**

Version 0.2 promotes the proof-of-concept overlay into a proper GIANTS GUI and adds optional **HelperProfiles API v7** worker dispatch.

## Controls

- **Ctrl + Alt + D** — open Remote Dispatcher.
- **Ctrl + Alt + R** — start/stop the retained target remotely, including after closing the Dispatcher for a cinematic.

All vehicle/worker navigation is handled inside the GUI, so normal menu focus consumes arrows/D-pad rather than moving the player or camera.

## Dispatcher GUI

The left list shows compatible owned vehicles with:

- vehicle name;
- AutoDrive/Courseplay capability;
- ready/active state;
- assigned worker;
- current AD destination or CP course.

The right list shows **AUTO** plus enabled HelperProfiles workers when API v7 is available.

Buttons provide:

- automation selection (AD/CP);
- worker assignment;
- dispatch/stop;
- close.

## HelperProfiles integration

`AUTO` keeps normal HelperProfiles/game helper selection.

A named assignment such as `MT635 -> Rhys` uses HelperProfiles API v7 `beginPreferredHire()` / `endPreferredHire()` around the synchronous AutoDrive/Courseplay start. The scoped request is fail-closed: if Rhys is active, off roster, or unavailable, the dispatch fails rather than silently substituting another worker.

The normal HelperProfiles selected worker is not changed.

Worker assignments are runtime/session state in this first GUI build; save persistence can be added after the interaction is proven.

## Remote vehicle activation

The v0.1.0.4 wake logic is retained. Remote Dispatcher calls `raiseActive()` before/after starting automation and briefly keeps the vehicle active so distant AutoDrive/Courseplay tasks begin without requiring player proximity.

Single-player only for the current prototype.
