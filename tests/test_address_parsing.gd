extends TestCase

const DEFAULT_PORT := EnetDirectConnector.DEFAULT_PORT


func _parse(text: String) -> Dictionary:
	return EnetDirectConnector.parse_address(text)


func test_ipv4_with_and_without_port() -> void:
	check_eq(_parse("85.12.34.56:5000"), {"host": "85.12.34.56", "port": 5000}, "ip:port")
	check_eq(_parse(" 85.12.34.56 "), {"host": "85.12.34.56", "port": DEFAULT_PORT}, "bare ip uses default port, trims spaces")


func test_hostname() -> void:
	check_eq(_parse("my-pc.tail1234.ts.net:24642"), {"host": "my-pc.tail1234.ts.net", "port": 24642}, "hostname:port")


func test_ipv6() -> void:
	check_eq(_parse("[2001:db8::1]:5000"), {"host": "2001:db8::1", "port": 5000}, "bracketed ipv6 with port")
	check_eq(_parse("[::1]"), {"host": "::1", "port": DEFAULT_PORT}, "bracketed ipv6 without port")
	check_eq(_parse("2001:db8::1"), {"host": "2001:db8::1", "port": DEFAULT_PORT}, "bare ipv6")


func test_invalid() -> void:
	for text in ["", "   ", "1.2.3.4:", "1.2.3.4:abc", "1.2.3.4:70000", "1.2.3.4:0", "[::1", "[::1]x", "a b:5000"]:
		check(_parse(text).is_empty(), "'%s' must be rejected" % text)
