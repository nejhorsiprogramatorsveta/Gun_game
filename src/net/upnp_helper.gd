class_name UpnpHelper
extends RefCounted
## Asks the home router (UPnP) to forward ONE UDP port to this computer and removes the
## forwarding again. Router discovery can take 10+ seconds, so it runs in a background thread.
## Security (PLAN.md section S): a single port, a time-limited lease (expires by itself if
## the game crashes) and removal as soon as hosting ends.

## {"mapped": bool, "external_ip": String}; emitted on the main thread, not after close_port().
signal finished(result: Dictionary)

const LEASE_SECONDS := 2 * 60 * 60
const DISCOVER_TIMEOUT_MS := 2000
const DESCRIPTION := "gun_game"

## Helpers closed while their thread still runs; kept alive here until the thread ends.
static var _closing: Array[UpnpHelper] = []

var _thread: Thread
var _mutex := Mutex.new()
## Guarded by _mutex (shared between the main and the worker thread).
var _upnp: UPNP
var _mapped_port := 0
var _closed := false


func open_port(port: int) -> void:
	_thread = Thread.new()
	_thread.start(_open_in_thread.bind(port))


## Never blocks: if discovery is still running, the worker removes the mapping itself.
func close_port() -> void:
	_mutex.lock()
	_closed = true
	var upnp := _upnp
	var port := _mapped_port
	_mapped_port = 0
	_mutex.unlock()
	if port != 0:
		upnp.delete_port_mapping(port, "UDP")
	# Any not-yet-joined thread (running or just finished) must be joined later.
	if _thread and not _closing.has(self):
		_closing.append(self)


## Call before the game quits so no worker is killed half-way (blocks a few seconds at most).
static func wait_for_all() -> void:
	for helper in _closing.duplicate():
		helper._join_thread()


func _open_in_thread(port: int) -> void:
	var result := {"mapped": false, "external_ip": ""}
	var upnp := UPNP.new()
	var gateway_ok := upnp.discover(DISCOVER_TIMEOUT_MS) == UPNP.UPNP_RESULT_SUCCESS \
		and upnp.get_gateway() != null and upnp.get_gateway().is_valid_gateway()
	if gateway_ok and not _is_closed():
		var error := upnp.add_port_mapping(port, port, DESCRIPTION, "UDP", LEASE_SECONDS)
		if error == UPNP.UPNP_RESULT_ONLY_PERMANENT_LEASE_SUPPORTED:
			# Old routers only accept permanent mappings; close_port() still removes it.
			error = upnp.add_port_mapping(port, port, DESCRIPTION, "UDP", 0)
		if error == UPNP.UPNP_RESULT_SUCCESS:
			result = {"mapped": true, "external_ip": upnp.query_external_address()}
			_mutex.lock()
			var closed_meanwhile := _closed
			if not closed_meanwhile:
				_upnp = upnp
				_mapped_port = port
			_mutex.unlock()
			if closed_meanwhile:
				upnp.delete_port_mapping(port, "UDP")
	_on_thread_done.call_deferred(result)


func _is_closed() -> bool:
	_mutex.lock()
	var closed := _closed
	_mutex.unlock()
	return closed


func _on_thread_done(result: Dictionary) -> void:
	_join_thread()
	if not _is_closed():
		finished.emit(result)


func _join_thread() -> void:
	if _thread:
		_thread.wait_to_finish()
		_thread = null
	_closing.erase(self)
