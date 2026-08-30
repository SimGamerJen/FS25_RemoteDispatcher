# Remote Dispatcher early alpha / beta release gate

## Early alpha gate

The first public alpha can be published when all items below are confirmed on a clean save load:

- [x] Compatible owned AutoDrive/Courseplay vehicles are discovered remotely.
- [x] The in-game selector can retain and cycle a target without entering the vehicle.
- [x] `Ctrl + Alt + R` can start a prepared AutoDrive task at distance.
- [x] Distant vehicles are woken so player proximity is not required for movement.
- [x] Management is separate from the live cinematic target.
- [x] HelperProfiles API v7 can assign a specific available worker without changing normal HProfs selection.
- [x] Named-worker dispatch is fail-closed when that worker is unavailable.
- [x] Management and selector UI are usable and HUD visibility is respected.
- [x] Per-save automation/worker assignments and retained target are implemented using vehicle `uniqueId`.
- [x] `rdStatus` diagnostics are available.
- [x] CI validates XML/source references and builds the distributable ZIP.
- [ ] Clean `log.txt` after load, management open/close, target cycling, AD start/stop, save/reload, and second dispatch.
- [ ] Confirm persisted assignment/target restoration in-game after a full FS25 restart.
- [ ] Confirm Courseplay remote start/stop on at least one straightforward fieldwork job.
- [ ] Confirm AUTO worker dispatch still follows normal HelperProfiles/game selection.
- [ ] Confirm named-worker unavailability produces a clear rejection and no substitute hire.

### Alpha known limitations

- Single-player only.
- Remote Dispatcher does not configure AD destinations or build CP jobs; tasks must already be prepared.
- AD/CP compatibility is based on their current public/runtime interfaces and may need adapter updates when those mods change.
- English UI only for the initial alpha.
- No ModHub submission is implied by the GitHub alpha.

## Beta gate

Before calling the project beta, add broader compatibility confidence rather than more features:

- [ ] Test multiple maps and at least 10 distinct vehicle types/configurations.
- [ ] Exercise both AD and CP repeatedly across save/reload cycles.
- [ ] Test selling a configured vehicle and buying/configuring another vehicle.
- [ ] Test with HelperProfiles absent, present, and with workers OFF roster/ACTIVE.
- [ ] Test input remapping and gamepad navigation.
- [ ] Review user-facing wording/localisation strategy.
- [ ] Add a final mod icon and choose/document the repository licence.
- [ ] Decide whether per-save stale vehicle records should be pruned automatically.
- [ ] Review adapter compatibility against then-current AutoDrive/Courseplay releases.

## ModHub gate (later)

A ModHub submission should be treated separately from the GitHub alpha/beta. It would require the normal GIANTS packaging/content review, dependency/compatibility decisions, localisation and any requested code/style changes.
