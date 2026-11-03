class_name Connector
extends RefCounted
## How peers reach each other (direct IP over LAN/Tailscale today, maybe a relay later).
## Only connectors know about transports; Session and gameplay only see the returned
## MultiplayerPeer, so a new connection method never touches gameplay code.

## Returns a listening peer, or null if hosting failed (e.g. port in use).
func host(_port: int) -> MultiplayerPeer:
	return null


## Returns a connecting peer, or null if join_info is invalid or the attempt failed.
func join(_join_info: String) -> MultiplayerPeer:
	return null


## Releases extras opened by host()/join(). The MultiplayerPeer itself is closed by Session.
func close() -> void:
	pass


## What the host can send to friends so they can join, best option first:
## [{"kind": &"tailscale" | &"lan", "address": "ip:port"}].
func share_addresses(_port: int) -> Array[Dictionary]:
	return []
