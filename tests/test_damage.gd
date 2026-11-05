extends TestCase
## Damage percent (user 2026-11-05): hits add damage, knockback grows with it, 100 % = max.


func _target(character_id: StringName = &"vichr") -> Player:
	var player := Player.new()
	player.character = ContentDB.get_character(character_id)
	return player


func test_multiplier_grows_to_the_maximum_at_100_percent() -> void:
	check_eq(CombatRules.damage_multiplier(0.0), 1.0, "0 %: the weapon's own knockback")
	check(is_equal_approx(CombatRules.damage_multiplier(50.0), 1.75), "50 %: halfway")
	check_eq(CombatRules.damage_multiplier(100.0), CombatRules.MAX_DAMAGE_KNOCKBACK, "100 %: the highest knockback")
	check_eq(CombatRules.damage_multiplier(250.0), CombatRules.MAX_DAMAGE_KNOCKBACK, "never above the maximum")


func test_hits_add_damage_and_push_harder_each_time() -> void:
	var target := _target()
	var push := Vector2(800, 0)
	target.take_hit(push, 10.0)
	check_eq(target.velocity, push, "first hit: exactly the configured knockback")
	check_eq(target.damage, 10.0, "damage added after the push")
	target.velocity = Vector2.ZERO
	target.take_hit(push, 10.0)
	check(target.velocity.x > push.x, "the second hit pushes harder (%.0f)" % target.velocity.x)
	for i in 20:
		target.take_hit(push, 10.0)
	check_eq(target.damage, CombatRules.MAX_DAMAGE, "damage stops at 100 %")
	target.reset_to(Vector2.ZERO)
	check_eq(target.damage, 0.0, "respawn: back to 0 %")
	target.free()


func test_shield_reduces_damage_and_knockback() -> void:
	var balvan := _target(&"balvan")
	balvan.ability_time_left = 1.0  # shield active
	balvan.take_hit(Vector2(1000, 0), 10.0)
	check(is_equal_approx(balvan.velocity.x, 200.0), "knockback x0.2 behind the shield")
	check(is_equal_approx(balvan.damage, 2.0), "and only a fifth of the damage")
	balvan.free()


func test_every_weapon_and_the_shockwave_deal_damage() -> void:
	for id in ContentDB.character_ids():
		var weapon := ContentDB.get_character(id).weapon
		check(weapon.damage > 0.0 and weapon.damage * weapon.pellets <= 15.0, "%s: damage per shot %.1f %%" % [weapon.id, weapon.damage * weapon.pellets])
	var vichr := _target(&"vichr")
	var other := _target(&"jiskra")
	other.position = Vector2(100, 0)
	(vichr.character.ability as ShockwaveAbility).activate(vichr, [vichr, other])
	check(other.damage > 0.0, "the shockwave adds damage too")
	vichr.free()
	other.free()


func test_damage_reaches_clients() -> void:
	var host := _target()
	host.take_hit(Vector2(100, 0), 37.4)
	var state: Dictionary = NetCodec.decode_snapshot(NetCodec.encode_snapshot(1, 0, [host.snapshot_state()] as Array[Dictionary])).states[0]
	check_eq(state.damage, 37.0, "whole percent in the snapshot")
	var client := _target()
	client._apply_state(state)
	check_eq(client.damage, 37.0, "client shows it")
	host.free()
	client.free()
