class_name SnapshotTimeline
extends RefCounted
## When to show a remote player (PLAN.md D.4), one timeline per player. States are placed on
## the timeline where they were MADE, not on their arrival time, so states that arrive in
## bunches (Wi-Fi power saving, play tests 2026-11-05) still play back evenly:
## - the host's own player: the host's tick;
## - a player controlled by a client: that client's input sequence (last_seq). The host
##   simulates a client's inputs as soon as they arrive, in bunches on bad Wi-Fi; on the
##   owner's input timeline the motion still looks exactly as smooth as it was played.
## The display delay follows the measured jitter: short on a clean LAN, up to MAX_DELAY_MS.

## Snapshots come every physics tick (MatchController.SNAPSHOT_EVERY_TICKS).
const SNAPSHOT_INTERVAL_MS := 1000.0 / 60.0
## Kept low on purpose: hits are decided on the host's current positions, so every ms of
## display delay makes moving players harder to hit. Short gaps are extrapolated instead.
const MIN_DELAY_MS := 40.0
const MAX_DELAY_MS := 200.0
const MARGIN_MS := 10.0
## How fast the delay may change (ms per second): grows fast when bunches appear, shrinks
## slowly, so remote players never visibly speed up or slow down.
const GROW_RATE := 200.0
const SHRINK_RATE := 25.0

var clock := JitterClock.new()
var delay_ms := float(RemoteInterpolator.INTERPOLATION_DELAY_MS)
var min_delay_ms := MIN_DELAY_MS
var _unwrapped_seq := -1


func _init(minimum_delay_ms: float = MIN_DELAY_MS) -> void:
	min_delay_ms = minimum_delay_ms


## Host time of a snapshot tick (ms).
static func tick_ms(tick: int) -> float:
	return tick * 1000.0 / Engine.physics_ticks_per_second


func observe(tick: int, arrival_ms: int) -> void:
	clock.observe(tick_ms(tick), arrival_ms)


func observe_ms(sender_ms: float, arrival_ms: int) -> void:
	clock.observe(sender_ms, arrival_ms)


## Owner time (ms) of an input sequence number (16-bit, unwrapped across calls).
func seq_ms(seq: int) -> float:
	if _unwrapped_seq < 0:
		_unwrapped_seq = seq
	else:
		var step := (seq - (_unwrapped_seq & 0xFFFF)) & 0xFFFF
		if step >= 0x8000:
			return tick_ms(_unwrapped_seq - (0x10000 - step))  # older than the newest seen
		_unwrapped_seq += step
	return tick_ms(_unwrapped_seq)


## Delay that keeps a newer snapshot available for 90 % of arrivals (the rest extrapolate).
func target_delay_ms() -> float:
	return clampf(clock.jitter_ms() + SNAPSHOT_INTERVAL_MS + MARGIN_MS, min_delay_ms, MAX_DELAY_MS)


## Every frame: move the delay smoothly towards the target.
func update(delta: float) -> void:
	if not clock.has_data():
		return
	var target := target_delay_ms()
	delay_ms = move_toward(delay_ms, target, (GROW_RATE if target > delay_ms else SHRINK_RATE) * delta)


## Host time to display at local `now_ms`.
func render_time(now_ms: int) -> float:
	return clock.sender_time(now_ms) - delay_ms
