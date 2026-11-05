class_name ConnectionLog
extends Node
## Diagnostics: writes connection and session events to the game log (DiagLog), so a play
## session where someone could not join or got disconnected can be analysed afterwards
## (docs/PLAYTEST.md). Child of the Session autoload; only listens to signals.
## Logs peer ids, phases, durations and reasons, never IP addresses or player names.

const PHASE_NAMES := ["offline", "connecting", "lobby", "in_match", "results"]

var _phase_start_ms := 0
var _previous_phase := 0
## peer_id -> connect time (msec)
var _peer_since: Dictionary[int, int] = {}


func _init() -> void:
	name = "ConnectionLog"


func _ready() -> void:
	DiagLog.event("sys", DiagLog.system_info())
	Session.phase_changed.connect(_on_phase_changed)
	Session.ended.connect(func(message: String) -> void:
		DiagLog.event("conn", "session ended: %s" % (message if not message.is_empty() else "left on purpose")))
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connection_failed.connect(func() -> void: DiagLog.event("conn", "connection failed (no answer from the host)"))
	multiplayer.server_disconnected.connect(func() -> void:
		DiagLog.event("conn", "host disconnected after %ds in %s" % [_seconds_in_phase(), PHASE_NAMES[Session.phase]]))
	var api := multiplayer as SceneMultiplayer
	api.peer_authenticating.connect(func(id: int) -> void: DiagLog.event("conn", "peer %d: handshake started" % id))
	api.peer_authentication_failed.connect(func(id: int) -> void: DiagLog.event("conn", "peer %d: handshake failed or timed out" % id))


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
		text += " players=%d arena=%s mode=%s" % [Session.match_slots.size(), Session.arena_id, "2v2" if Session.team_mode else "ffa"]
	DiagLog.event("conn", text)
	_previous_phase = phase
	_phase_start_ms = Time.get_ticks_msec()


func _on_peer_connected(id: int) -> void:
	_peer_since[id] = Time.get_ticks_msec()
	DiagLog.event("conn", "peer %d connected (%d in lobby)" % [id, Session.players.size()])


func _on_peer_disconnected(id: int) -> void:
	var seconds: int = (Time.get_ticks_msec() - _peer_since.get(id, Time.get_ticks_msec())) / 1000
	_peer_since.erase(id)
	DiagLog.event("conn", "peer %d disconnected after %ds during %s" % [id, seconds, PHASE_NAMES[Session.phase]])


func _seconds_in_phase() -> int:
	return (Time.get_ticks_msec() - _phase_start_ms) / 1000
