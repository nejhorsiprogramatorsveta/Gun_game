class_name ConnectionLog
extends Node
## Diagnostics: writes connection and session events to the game log (DiagLog), so a play
## session where someone could not join, lagged or got disconnected can be analysed
## afterwards (docs/PLAYTEST.md). Child of the Session autoload; only listens to signals,
## plus an ENet ping line every LOBBY_STATS_MS outside of matches (NetLog covers matches).
## Logs peer ids, slots, characters, phases, durations and reasons - never IPs or names.

const PHASE_NAMES := ["offline", "connecting", "lobby", "in_match", "results"]
const LOBBY_STATS_MS := 10000

var _phase_start_ms := 0
var _previous_phase := 0
var _last_stats_ms := 0
## peer_id -> connect time (msec)
var _peer_since: Dictionary[int, int] = {}


func _init() -> void:
	name = "ConnectionLog"


func _ready() -> void:
	DiagLog.install()
	DiagLog.event("sys", "game started build=%s" % BuildInfo.build_id())
	Session.phase_changed.connect(_on_phase_changed)
	Session.ended.connect(func(message: String) -> void:
		DiagLog.event("conn", "session ended: %s" % (message if not message.is_empty() else "left on purpose")))
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connection_failed.connect(func() -> void:
		DiagLog.event("conn", "connection failed after %dms (no answer from the host: wrong address, host's firewall, Tailscale off, different network?)" % (Time.get_ticks_msec() - _phase_start_ms)))
	multiplayer.server_disconnected.connect(func() -> void:
		DiagLog.event("conn", "host disconnected after %ds in %s" % [_seconds_in_phase(), PHASE_NAMES[Session.phase]]))
	var api := multiplayer as SceneMultiplayer
	api.peer_authenticating.connect(func(id: int) -> void: DiagLog.event("conn", "peer %d: handshake started" % id))
	api.peer_authentication_failed.connect(func(id: int) -> void: DiagLog.event("conn", "peer %d: handshake failed or timed out" % id))


func _notification(what: int) -> void:
	if Session == null or Session.phase == Session.Phase.OFFLINE:
		return
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			DiagLog.event("sys", "window lost focus (in %s)" % PHASE_NAMES[Session.phase])
		NOTIFICATION_APPLICATION_FOCUS_IN:
			DiagLog.event("sys", "window got focus")
		NOTIFICATION_WM_CLOSE_REQUEST:
			DiagLog.event("sys", "game window closed")
			DiagLog.flush()


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_stats_ms < LOBBY_STATS_MS:
		return
	_last_stats_ms = now
	if Session.phase != Session.Phase.LOBBY and Session.phase != Session.Phase.RESULTS:
		return
	var parts: PackedStringArray = []
	var peers: Array = multiplayer.get_peers() if multiplayer.is_server() else [1]
	for peer_id: int in peers:
		var stats := EnetDirectConnector.peer_stats(multiplayer.multiplayer_peer, peer_id)
		if not stats.is_empty():
			parts.append("peer %d rtt=%dms var=%dms loss=%.1f%%" % [peer_id, stats.rtt, stats.rtt_var, stats.loss])
	if not parts.is_empty():
		DiagLog.event("conn", "%s link: %s" % [PHASE_NAMES[Session.phase], " | ".join(parts)])


func _on_phase_changed(phase: int) -> void:
	var text := "phase %s -> %s after %ds" % [PHASE_NAMES[_previous_phase], PHASE_NAMES[phase], _seconds_in_phase()]
	if _previous_phase == Session.Phase.CONNECTING and phase == Session.Phase.LOBBY:
		text += " (connected in %dms)" % (Time.get_ticks_msec() - _phase_start_ms)
	if phase == Session.Phase.LOBBY and _previous_phase == Session.Phase.OFFLINE and Session.is_host():
		var kinds: PackedStringArray = []
		for entry in Session.share_addresses():
			kinds.append(String(entry.kind))
		text += " hosting port=%d shareable=%s" % [Session.host_port, ",".join(kinds) if not kinds.is_empty() else "none"]
	if phase == Session.Phase.IN_MATCH:
		text += " arena=%s mode=%s %s" % [Session.arena_id, "2v2" if Session.team_mode else "ffa", _slots_text()]
	if phase == Session.Phase.RESULTS and not Session.match_results.is_empty():
		var winner: Dictionary = Session.match_results[0]
		text += " winner_team=%d players=%d" % [winner.get("team", -1), Session.match_results.size()]
	DiagLog.event("conn", text)
	_previous_phase = phase
	_phase_start_ms = Time.get_ticks_msec()


## "me=slot1 slot0=stin/t0(host) slot1=vichr/t1 ..." (characters and teams, no names).
func _slots_text() -> String:
	var parts: PackedStringArray = []
	var me := multiplayer.get_unique_id()
	for peer_id: int in Session.match_slots:
		var entry: Dictionary = Session.players.get(peer_id, {})
		var text := "slot%d=%s/t%d" % [Session.match_slots[peer_id], entry.get("character", "?"), entry.get("team", -1)]
		if peer_id == 1:
			text += "(host)"
		parts.append(text)
	parts.sort()
	return "me=slot%d %s" % [Session.match_slots.get(me, -1), " ".join(parts)]


func _on_peer_connected(id: int) -> void:
	_peer_since[id] = Time.get_ticks_msec()
	DiagLog.event("conn", "peer %d connected (%d in lobby)" % [id, Session.players.size()])


func _on_peer_disconnected(id: int) -> void:
	var seconds: int = (Time.get_ticks_msec() - _peer_since.get(id, Time.get_ticks_msec())) / 1000
	_peer_since.erase(id)
	DiagLog.event("conn", "peer %d disconnected after %ds during %s" % [id, seconds, PHASE_NAMES[Session.phase]])


func _seconds_in_phase() -> int:
	return (Time.get_ticks_msec() - _phase_start_ms) / 1000
