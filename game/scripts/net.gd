# 네트워크 매니저 (오토로드): 솔로/호스트/게스트 모드 관리
extends Node

enum Mode { SOLO, HOST, GUEST }

const DEFAULT_PORT := 7777
const MAX_PLAYERS := 4

var mode: int = Mode.SOLO


func is_host() -> bool:
	return mode == Mode.HOST


func is_guest() -> bool:
	return mode == Mode.GUEST


func active() -> bool:
	return mode != Mode.SOLO


func host_game(port := DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS - 1)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	mode = Mode.HOST
	return OK


func join_game(ip: String, port := DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	mode = Mode.GUEST
	return OK


func reset() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	mode = Mode.SOLO
