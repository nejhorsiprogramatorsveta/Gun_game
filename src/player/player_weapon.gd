class_name PlayerWeapon
extends RefCounted
## Runtime state of a player's weapon: fire cooldown, magazine and reload (PLAN.md T.3).
## Simulated by the host AND by the own client's prediction (Player.tick_weapon), so the
## shooter's shots, ammo and reload happen on the same ticks on both. Other clients only
## show what the snapshot carries (ammo, reloading and firing flags).

## Seconds until the weapon may fire again.
var fire_cooldown := 0.0
## Rounds left in the magazine and seconds of reloading left (authority decides; clients
## get both via the snapshot).
var ammo := 0
var reload_time_left := 0.0
## Only drive the animations: reload progress and the shooting pose (Player.is_firing).
var reload_started_ms := -100000
var last_fire_ms := -100000

var _player: Player


func _init(player: Player) -> void:
	_player = player


## Weapon timers are kept on the snapshot's grid (NetCodec.WEAPON_TIMER_UNITS), so the host
## and the replaying client compare exactly the same numbers (0.1 s - 6 ticks is not 0 in
## floating point and would otherwise fire a tick apart).
static func count_down(seconds: float, delta: float) -> float:
	var left := roundf((seconds - delta) * NetCodec.WEAPON_TIMER_UNITS)
	return left / NetCodec.WEAPON_TIMER_UNITS if left > 0.0 else 0.0


## One tick: cooldown and reload, then a shot if wanted and allowed. True when a shot is
## fired (the caller adds the recoil).
func tick(wants_to_fire: bool, delta: float) -> bool:
	fire_cooldown = count_down(fire_cooldown, delta)
	if tick_reload(delta):
		return false
	var weapon := _player.current_weapon()
	if weapon == null or not wants_to_fire or fire_cooldown > 0.0:
		return false
	fire_cooldown = roundf(CombatRules.fire_interval(weapon) * NetCodec.WEAPON_TIMER_UNITS) / NetCodec.WEAPON_TIMER_UNITS
	last_fire_ms = Time.get_ticks_msec()
	use_round()
	return true


## Full magazine, no reload (spawn and every respawn).
func refill() -> void:
	var weapon := _player.current_weapon()
	ammo = weapon.magazine_size if weapon else 0
	reload_time_left = 0.0


func is_reloading() -> bool:
	return reload_time_left > 0.0


## Authority, every tick: counts the reload down; true while the weapon cannot fire yet.
func tick_reload(delta: float) -> bool:
	if reload_time_left <= 0.0:
		return false
	reload_time_left = count_down(reload_time_left, delta)
	if reload_time_left > 0.0:
		return true
	refill()
	return false


## Authority: one shot fired; the last round starts the reload.
func use_round() -> void:
	ammo = maxi(ammo - 1, 0)
	var weapon := _player.current_weapon()
	if ammo == 0 and weapon:
		reload_time_left = weapon.reload_time
		reload_started_ms = Time.get_ticks_msec()


## 0..1 while reloading (for the animation), -1 otherwise.
func reload_progress() -> float:
	var weapon := _player.current_weapon()
	if not is_reloading() or weapon == null:
		return -1.0
	return clampf((Time.get_ticks_msec() - reload_started_ms) / (weapon.reload_time * 1000.0), 0.0, 1.0)


## Before replaying inputs: the exact timers, so replayed shots (recoil) happen on the same
## ticks as on the host.
func restore(state: Dictionary) -> void:
	fire_cooldown = state.get("fire_cooldown", 0.0)
	reload_time_left = state.get("reload_time_left", reload_time_left)


## Showing a snapshot: rounds, the shooting pose and the reload animation. Clients only
## show the reload; its exact timing stays on the host.
func show_state(state: Dictionary) -> void:
	if state.get("firing", false):
		last_fire_ms = Time.get_ticks_msec()
	ammo = state.get("ammo", ammo)
	var reloading: bool = state.get("reloading", false)
	if reloading and not is_reloading():
		reload_started_ms = Time.get_ticks_msec()
	var weapon := _player.current_weapon()
	reload_time_left = (weapon.reload_time if weapon else 1.0) if reloading else 0.0
