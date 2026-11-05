extends TestCase
## Lobby character confirmation helpers (CharacterChoice).


func test_only_confirmed_characters_block_others() -> void:
	var lobby := {1: {"character": "stin", "ready": true}, 2: {"character": "vichr", "ready": false}}
	check_eq(CharacterChoice.confirmed_by(lobby, "stin", 2), 1, "Stín is confirmed by the host")
	check_eq(CharacterChoice.confirmed_by(lobby, "vichr", 1), 0, "an unconfirmed placeholder blocks nobody")
	check_eq(CharacterChoice.holder(lobby, "vichr", 1), 2, "but it still has a holder")
	check_eq(CharacterChoice.confirmed_by(lobby, "stin", 1), 0, "own character is never 'taken'")
	check(not CharacterChoice.all_confirmed(lobby), "the match waits for player 2")
	lobby[2].ready = true
	check(CharacterChoice.all_confirmed(lobby), "everyone confirmed")
