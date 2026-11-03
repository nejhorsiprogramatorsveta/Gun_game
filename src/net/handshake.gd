class_name Handshake
## Join handshake messages: built and checked here, sent by Session through
## SceneMultiplayer authentication (raw bytes, not RPC; RPCs are matched by method index,
## so a peer on another build might not even decode an RPC hello).
## Pure functions without network state, so they are unit-testable.
## Security (PLAN.md section S): size limit, no object decoding, type-safe comparisons.

## Handshake messages are tiny; anything bigger is ignored unparsed.
const MAX_MESSAGE_BYTES := 512
const REJECT_REASONS: PackedStringArray = ["ERROR_VERSION_MISMATCH", "ERROR_WRONG_CODE", "ERROR_LOBBY_FULL", "ERROR_MATCH_IN_PROGRESS"]
## Room code: 6 characters from 32 unambiguous symbols (no 0/O, 1/I) = ~1 billion combinations.
const ROOM_CODE_LENGTH := 6
const ROOM_CODE_ALPHABET := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"


## Cryptographically secure, so the code cannot be predicted.
static func generate_room_code() -> String:
	var code := ""
	for byte in Crypto.new().generate_random_bytes(ROOM_CODE_LENGTH):
		code += ROOM_CODE_ALPHABET[byte % ROOM_CODE_ALPHABET.length()]  # 256 % 32 == 0: unbiased
	return code


## Splits what the host shared ("address#CODE") into [address, CODE]; code may be empty.
static func split_join_text(join_text: String) -> PackedStringArray:
	var parts := join_text.strip_edges().split("#", true, 1)
	var code := parts[1].strip_edges().to_upper() if parts.size() > 1 else ""
	return [parts[0].strip_edges(), code]


static func make_hello(room_code: String, player_name: String) -> PackedByteArray:
	return var_to_bytes({"protocol": BuildInfo.PROTOCOL_VERSION, "build": BuildInfo.build_id(), "code": room_code, "name": player_name})


static func make_accept() -> PackedByteArray:
	return var_to_bytes({"ok": true})


static func make_reject(reason: String) -> PackedByteArray:
	return var_to_bytes({"ok": false, "reason": reason, "build": BuildInfo.build_id()})


## Returns the message, or an empty dictionary if it is too big or not a dictionary.
static func decode(data: PackedByteArray) -> Dictionary:
	# Every encoded Variant starts with a 4-byte header; shorter data is garbage.
	if data.size() < 4 or data.size() > MAX_MESSAGE_BYTES:
		return {}
	# bytes_to_var() never decodes objects, so untrusted data cannot create code.
	var message: Variant = bytes_to_var(data)
	return message if message is Dictionary else {}


## Host side: "" if the hello matches this build and room, else the reject reason key.
static func check_hello(hello: Dictionary, room_code: String) -> String:
	if not (_value_is(hello, "protocol", BuildInfo.PROTOCOL_VERSION) and _value_is(hello, "build", BuildInfo.build_id())):
		return "ERROR_VERSION_MISMATCH"
	if not _value_is(hello, "code", room_code):
		return "ERROR_WRONG_CODE"
	return ""


static func requested_name(hello: Dictionary) -> String:
	return str(hello.get("name", ""))


static func is_accept(reply: Dictionary) -> bool:
	return _value_is(reply, "ok", true)


## Client side: translated explanation of a rejection.
static func rejection_text(reply: Dictionary) -> String:
	var reason := str(reply.get("reason", ""))
	if reason not in REJECT_REASONS:
		reason = "ERROR_VERSION_MISMATCH"
	var text := TranslationServer.translate(reason)
	return text.format({"mine": BuildInfo.build_id(), "host": str(reply.get("build", "?"))})


## Type-safe equality for values received from the network.
static func _value_is(data: Dictionary, key: String, expected: Variant) -> bool:
	var value: Variant = data.get(key)
	return typeof(value) == typeof(expected) and value == expected
