# 네트워크 매니저 (오토로드): 솔로/호스트/게스트 모드 관리
extends Node

enum Mode { SOLO, HOST, GUEST }

const DEFAULT_PORT := 7777
const MAX_PLAYERS := 4

var mode: int = Mode.SOLO
var last_ip := ""     # 게스트가 찾아간 호스트 주소 (접속 화면에 보여 준다)


func is_host() -> bool:
	return mode == Mode.HOST


func is_guest() -> bool:
	return mode == Mode.GUEST


func active() -> bool:
	return mode != Mode.SOLO


# 실제로 **연결이 붙어 있는가**. active()는 모드만 보므로, 접속 중이거나
# (게스트가 방을 찾는 동안) 끊긴 뒤에도 참이다. RPC는 붙어 있을 때만
# 보낼 수 있으니 — 아니면 "not connected" 오류가 매 프레임 쏟아진다 —
# 무언가를 rpc로 보내기 전에는 이쪽을 본다.
func connected() -> bool:
	if mode == Mode.SOLO or multiplayer.multiplayer_peer == null:
		return false
	return multiplayer.multiplayer_peer.get_connection_status() \
		== MultiplayerPeer.CONNECTION_CONNECTED


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
	last_ip = "%s:%d" % [ip, port]
	return OK


func reset() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	mode = Mode.SOLO
