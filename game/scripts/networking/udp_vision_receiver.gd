class_name UdpVisionReceiver
extends Node

const MAX_PACKET_BYTES := 8192

var server := UDPServer.new()
var peers: Array[PacketPeerUDP] = []
var latest: Dictionary = {}
var latest_sequence := -1
var latest_session_id := ""
var retired_session_ids: Array[String] = []
var last_packet_ms := -1
var packet_rate := 0.0
var _packets_this_second := 0
var _rate_elapsed := 0.0
var enabled := true


func _ready() -> void:
    var port := _argument_port("--udp-port=", 42420)
    var error := server.listen(port, "127.0.0.1")
    if error != OK:
        push_error("Vision UDP listen failed: %s" % error)


func _process(delta: float) -> void:
    if not enabled:
        return
    server.poll()
    while server.is_connection_available():
        if peers.size() >= 4:
            peers.pop_front()
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
    if packet.size() > MAX_PACKET_BYTES:
        return
    var parsed = JSON.parse_string(packet.get_string_from_utf8())
    if not parsed is Dictionary or parsed.get("v") != 1 or parsed.get("kind") != "input":
        return
    var candidate = parsed.get("data", {})
    if not candidate is Dictionary:
        return
    var data: Dictionary = candidate
    var session_id := str(data.get("session_id", ""))
    if session_id.is_empty() or session_id in retired_session_ids:
        return
    if session_id != latest_session_id:
        if not latest_session_id.is_empty():
            retired_session_ids.append(latest_session_id)
            if retired_session_ids.size() > 4:
                retired_session_ids.pop_front()
        latest_session_id = session_id
        latest_sequence = -1
    var sequence := int(data.get("sequence", -1))
    if sequence < 0 or sequence <= latest_sequence:
        return
    for key in ["move", "aim_x", "aim_y", "aim_left_x", "aim_left_y", "aim_right_x", "aim_right_y", "pull", "two_hand_pull", "pose_confidence", "hand_confidence"]:
        var value = data.get(key, 0.0)
        if not value is int and not value is float:
            return
    for key in ["tracked", "jump", "crouch", "dodge_left", "dodge_right", "shield", "web_left", "web_right", "web_left_trigger", "web_right_trigger", "fist_left", "fist_right", "palm_open_left", "palm_open_right"]:
        if not data.get(key, false) is bool:
            return
    for key in ["gesture_left", "gesture_right"]:
        var gesture = data.get(key, "OPEN")
        if not gesture is String or str(gesture).length() > 24:
            return
    var hand_count = data.get("hand_count", 0)
    if not hand_count is int and not hand_count is float:
        return
    data["move"] = clampf(float(data.get("move", 0.0)), -1.0, 1.0)
    for key in ["aim_x", "aim_y", "aim_left_x", "aim_left_y", "aim_right_x", "aim_right_y", "pull", "two_hand_pull", "pose_confidence", "hand_confidence"]:
        data[key] = clampf(float(data.get(key, 0.0)), 0.0, 1.0)
    data["hand_count"] = clampi(int(hand_count), 0, 2)
    latest_sequence = sequence
    latest = data
    last_packet_ms = Time.get_ticks_msec()
    _packets_this_second += 1


func is_fresh(max_age_ms: int = 350) -> bool:
    return last_packet_ms >= 0 and Time.get_ticks_msec() - last_packet_ms < max_age_ms


static func _argument_port(prefix: String, fallback: int) -> int:
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with(prefix):
            var parsed := int(argument.trim_prefix(prefix))
            if parsed >= 1024 and parsed <= 65535:
                return parsed
    return fallback
