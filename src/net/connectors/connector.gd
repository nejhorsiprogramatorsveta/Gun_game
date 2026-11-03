class_name Connector
extends RefCounted
## How peers reach each other (direct IP, later a join-code relay, ...).
## Only connectors know about transports; Session and gameplay only see the returned
## MultiplayerPeer, so a new connection method never touches gameplay code.

## share_addresses() or internet_status() changed (e.g. a router answered).
signal share_info_changed


## Returns a listening peer, or null if hosting failed (e.g. port in use).
func host(_port: int) -> MultiplayerPeer:
	return null


## Returns a connecting peer, or null if join_info is invalid or the attempt failed.
func join(_join_info: String) -> MultiplayerPeer:
	return null


## Releases extras opened by host()/join() (e.g. router port forwarding).
## The MultiplayerPeer itself is closed by Session.
func close() -> void:
	pass


## What the host can send to friends so they can join, best option first:
## [{"kind": &"lan" | &"tailscale" | &"public" | &"ipv6", "address": "ip:port"}].
func share_addresses(_port: int) -> Array[Dictionary]:
	return []


## Whether friends on the internet can reach this host:
## &"" (unknown/not hosting), &"checking", &"open", &"failed", &"cgnat".
func internet_status() -> StringName:
	return &""
