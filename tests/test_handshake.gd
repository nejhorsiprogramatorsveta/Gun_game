extends TestCase
## Handshake: room code, join text and message checks (src/net/handshake.gd).


func test_room_code_format() -> void:
	var code := Handshake.generate_room_code()
	check_eq(code.length(), Handshake.ROOM_CODE_LENGTH, "code length")
	for character in code:
		check(Handshake.ROOM_CODE_ALPHABET.contains(character), "unexpected character " + character)


func test_room_codes_differ() -> void:
	var codes := {}
	for i in 50:
		codes[Handshake.generate_room_code()] = true
	check(codes.size() >= 49, "random codes should practically never repeat")


func test_split_join_text() -> void:
	check_eq(Handshake.split_join_text(" 1.2.3.4:5000#k7q2mx "), PackedStringArray(["1.2.3.4:5000", "K7Q2MX"]), "address + code, code upper-cased")
	check_eq(Handshake.split_join_text("1.2.3.4"), PackedStringArray(["1.2.3.4", ""]), "missing code")


func test_hello_accepted_only_with_same_build_and_code() -> void:
	var hello := Handshake.decode(Handshake.make_hello("ABCDEF", "Pepa"))
	check_eq(Handshake.check_hello(hello, "ABCDEF"), "", "matching hello is accepted")
	check_eq(Handshake.check_hello(hello, "ZZZZZZ"), "ERROR_WRONG_CODE", "wrong room code")
	hello.build = "0.0.0+other"
	check_eq(Handshake.check_hello(hello, "ABCDEF"), "ERROR_VERSION_MISMATCH", "different build")
	check_eq(Handshake.requested_name(hello), "Pepa", "name passes through")


func test_malicious_messages_are_ignored() -> void:
	var too_big := PackedByteArray()
	too_big.resize(Handshake.MAX_MESSAGE_BYTES + 1)
	check(Handshake.decode(too_big).is_empty(), "oversized message ignored")
	check(Handshake.decode(var_to_bytes([1, 2, 3])).is_empty(), "non-dictionary ignored")
	check(Handshake.decode(PackedByteArray([1, 2, 3])).is_empty(), "garbage ignored")
	var typed_wrong := {"protocol": str(BuildInfo.PROTOCOL_VERSION), "build": BuildInfo.build_id(), "code": "ABCDEF"}
	check_eq(Handshake.check_hello(typed_wrong, "ABCDEF"), "ERROR_VERSION_MISMATCH", "wrong value types never match")
	check(not Handshake.is_accept({"ok": "true"}), "string 'true' is not an accept")
