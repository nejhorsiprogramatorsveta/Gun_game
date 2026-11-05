class_name SnapshotTimeline
extends RefCounted
## Client: when to show remote players (PLAN.md D.4). Snapshots are placed on the HOST's
## timeline (their tick), not on their arrival time, so snapshots that arrive in bunches
## (Wi-Fi power saving, play tests 2026-11-05) still play back evenly. The display delay
## follows the measured jitter: ~50 ms on a clean LAN, up to MAX_DELAY_MS on a bursty link.

const SNAPSHOT_INTERVAL_MS := 1000.0 / 30.0
const MIN_DELAY_MS := 50.0
const MAX_DELAY_MS := 250.0
const MARGIN_MS := 15.0
## How fast the delay may change (ms per second): grows fast when bunches appear, shrinks
## slowly, so remote players never visibly speed up or slow down.
const GROW_RATE := 200.0
const SHRINK_RATE := 25.0

var clock := JitterClock.new()
var delay_ms := float(RemoteInterpolator.INTERPOLATION_DELAY_MS)


## Host time of a snapshot tick (ms).
static func tick_ms(tick: int) -> float:
	return tick * 1000.0 / Engine.physics_ticks_per_second


func observe(tick: int, arrival_ms: int) -> void:
	clock.observe(tick_ms(tick), arrival_ms)


## Delay that keeps a newer snapshot available for 90 % of arrivals.
func target_delay_ms() -> float:
	return clampf(clock.jitter_ms() + SNAPSHOT_INTERVAL_MS + MARGIN_MS, MIN_DELAY_MS, MAX_DELAY_MS)


## Every frame: move the delay smoothly towards the target.
func update(delta: float) -> void:
	if not clock.has_data():
		return
	var target := target_delay_ms()
	delay_ms = move_toward(delay_ms, target, (GROW_RATE if target > delay_ms else SHRINK_RATE) * delta)


## Host time to display at local `now_ms`.
func render_time(now_ms: int) -> float:
	return clock.sender_time(now_ms) - delay_ms
