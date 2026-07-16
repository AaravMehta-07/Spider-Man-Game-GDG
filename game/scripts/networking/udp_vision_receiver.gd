class_name UdpVisionReceiver
extends Node

var server := UDPServer.new()
var peers: Array[PacketPeerUDP] = []
var latest: Dictionary = {}
var latest_sequence := -1
var last_packet_ms := -1
var packet_rate := 0.0
var _packets_this_second := 0
var _rate_elapsed := 0.0
var enabled := true


func _ready() -> void:
    var error := server.listen(42420, "127.0.0.1")
    if error != OK:
        push_error("Vision UDP listen failed: %s" % error)


func _process(delta: float) -> void:
    if not enabled:
        return
    server.poll()
    while server.is_connection_available():
        peers.append(server.take_connection())
    for peer in peers:
        while peer.get_available_packet_count() > 0:
            _accept_packet(peer.get_packet())
    _rate_elapsed += delta
    if _rate_elapsed >= 1.0:
        packet_rate = _packets_this_second / _rate_elapsed
        _packets_this_second = 0
        _rate_elapsed = 0.0


func _accept_packet(packet: PackedByteArray) -> void:
    var parsed = JSON.parse_string(packet.get_string_from_utf8())
    if not parsed is Dictionary or parsed.get("v") != 1 or parsed.get("kind") != "input":
        return
    var data: Dictionary = parsed.get("data", {})
    var sequence := int(data.get("sequence", -1))
    if sequence <= latest_sequence:
        return
    latest_sequence = sequence
    latest = data
    last_packet_ms = Time.get_ticks_msec()
    _packets_this_second += 1


func is_fresh(max_age_ms: int = 350) -> bool:
    return last_packet_ms >= 0 and Time.get_ticks_msec() - last_packet_ms < max_age_ms
