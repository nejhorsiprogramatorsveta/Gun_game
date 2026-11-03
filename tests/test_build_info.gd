extends TestCase


func test_ci_build_uses_build_number() -> void:
	var saved := [BuildInfo.version, BuildInfo.build, BuildInfo.commit]
	BuildInfo.version = "0.1.0"
	BuildInfo.build = 24
	BuildInfo.commit = "abc1234"
	check_eq(BuildInfo.build_id(), "0.1.0+24", "build id uses the build number")
	check_eq(BuildInfo.display_string(), "0.1.0 (sestavení 24)", "friendly Czech display")
	BuildInfo.build = 0
	check_eq(BuildInfo.build_id(), "0.1.0+abc1234", "local runs fall back to the commit")
	BuildInfo.version = saved[0]
	BuildInfo.build = saved[1]
	BuildInfo.commit = saved[2]
