extends TestCase

const SessionScript := preload("res://src/autoload/session.gd")


func test_room_code_format() -> void:
	var code: String = SessionScript.generate_room_code()
	check_eq(code.length(), SessionScript.ROOM_CODE_LENGTH, "code length")
	for character in code:
		check(SessionScript.ROOM_CODE_ALPHABET.contains(character), "unexpected character " + character)


func test_room_codes_differ() -> void:
	var codes := {}
	for i in 50:
		codes[SessionScript.generate_room_code()] = true
	check(codes.size() >= 49, "random codes should practically never repeat")
