class_name CityBuilder
extends Node3D

var speed := 24.0
var mission_state: StringName = &"ATTRACT"
var player_lane := 0.0
var boss_health := 100.0
var boss_tension := 0.0
var _chunks: Array[Node3D] = []
var _props: Array[Node3D] = []
var _set_pieces: Array[Node3D] = []
var _rain: Array[MeshInstance3D] = []
var _cage: Array[MeshInstance3D] = []
var _boss: GreenGoblinVisual
var _boss_shadow: MeshInstance3D
var _gpu_rain: GPUParticles3D
var _traffic_follow: PathFollow3D
var _animation_player: AnimationPlayer
var _boss_reaction_offset := Vector3.ZERO
var _boss_reaction_rotation := Vector3.ZERO
var _boss_reaction_time := 0.0
var low_quality := false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
    _rng.seed = 7331
    _build_city()
    _build_rain()
    _build_gpu_rain()
    _build_traffic_and_animation()
    _build_boss()


func _process(delta: float) -> void:
    var active := mission_state in [&"CHASE", &"BOSS_INTRO", &"BOSS_COMBAT", &"FINISHER"]
    var travel := speed * delta if active else 2.0 * delta
    _move_looped(_chunks, travel, 210.0)
    _move_looped(_props, travel * 1.08, 190.0)
    _move_set_pieces(travel, delta)
    _move_rain(delta)
    if is_instance_valid(_traffic_follow):
        _traffic_follow.progress += delta * (10.0 if active else 3.0)
    _update_boss(delta)


func set_mission_state(value: StringName) -> void:
    mission_state = value


func set_player_lane(value: float) -> void:
    player_lane = clampf(value, -1.0, 1.0)


func set_boss_energy(health: float, tension: float) -> void:
    boss_health = health
    boss_tension = tension


func reset_dynamic_objects() -> void:
    for piece in _set_pieces:
        if is_instance_valid(piece):
            piece.queue_free()
    _set_pieces.clear()
    boss_health = 100.0
    boss_tension = 0.0
    _boss_reaction_offset = Vector3.ZERO
    _boss_reaction_rotation = Vector3.ZERO
    _boss_reaction_time = 0.0


func play_set_piece(kind: StringName) -> void:
    if kind in [&"boss_reveal", &"right_slash", &"overhead", &"energy", &"counter", &"debris", &"ground_wave"]:
        _pulse_boss(kind)
        if kind != &"boss_reveal":
            _spawn_piece(kind)
        return
    _spawn_piece(kind)


func show_boss_hit(heavy := false) -> void:
    if is_instance_valid(_boss):
        _boss.show_hit(heavy)


func _move_looped(items: Array[Node3D], travel: float, span: float) -> void:
    for item in items:
        item.position.z += travel
        if item.position.z > 30.0:
            item.position.z -= span


func _move_set_pieces(travel: float, delta: float) -> void:
    for piece in _set_pieces.duplicate():
        if not is_instance_valid(piece):
            _set_pieces.erase(piece)
            continue
        piece.position.z += travel * float(piece.get_meta("speed_scale", 1.28))
        piece.position.x += float(piece.get_meta("lateral_speed", 0.0)) * delta
        var velocity_y := float(piece.get_meta("velocity_y", 0.0))
        if piece.has_meta("gravity"):
            velocity_y += float(piece.get_meta("gravity")) * delta
            piece.set_meta("velocity_y", velocity_y)
            piece.position.y += velocity_y * delta
        var spin: Vector3 = piece.get_meta("spin", Vector3.ZERO)
        piece.rotation += spin * delta
        if piece.has_meta("life"):
            var life := float(piece.get_meta("life")) - delta
            piece.set_meta("life", life)
            if life <= 0.0:
                _set_pieces.erase(piece)
                piece.queue_free()
                continue
        if piece.has_meta("wobble"):
            piece.rotation.z += sin(Time.get_ticks_msec() * 0.006) * float(piece.get_meta("wobble")) * delta
        if piece.position.z > 15.0 or piece.position.y < -5.0:
            _set_pieces.erase(piece)
            piece.queue_free()


func _move_rain(delta: float) -> void:
    for streak in _rain:
        streak.position.y -= delta * 29.0
        streak.position.z += delta * 10.0
        if streak.position.y < -1.0:
            streak.position = Vector3(
                _rng.randf_range(-14.0, 14.0),
                _rng.randf_range(8.0, 19.0),
                _rng.randf_range(-52.0, 4.0)
            )


func _update_boss(delta: float) -> void:
    var visible := mission_state in [&"BOSS_INTRO", &"BOSS_COMBAT", &"FINISHER"]
    _boss.visible = visible
    _boss_shadow.visible = visible
    for strand in _cage:
        strand.visible = mission_state == &"FINISHER"
    if not visible:
        return
    _boss_reaction_time = maxf(0.0, _boss_reaction_time - delta)
    var reaction_weight := clampf(_boss_reaction_time / 0.35, 0.0, 1.0)
    var time := Time.get_ticks_msec() * 0.001
    _boss.position = Vector3(sin(time * 1.7) * 1.45, 6.1 + sin(time * 2.1) * 0.28, -16.0) + _boss_reaction_offset * reaction_weight
    _boss.rotation = Vector3(0, sin(time * 0.9) * 0.2, sin(time * 1.4) * 0.05) + _boss_reaction_rotation * reaction_weight
    _boss.scale = Vector3.ONE * (1.0 - boss_tension * 0.22)
    _boss_shadow.position = Vector3(_boss.position.x * 0.7, 0.02, _boss.position.z + 1.7)
    _boss.update_visual(delta, boss_health, boss_tension, mission_state)
    for index in _cage.size():
        var angle := float(index) / float(_cage.size()) * TAU
        var radius := 5.2 - boss_tension * 2.8
        _cage[index].position = _boss.position + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
        _cage[index].rotation = Vector3(0.18 * sin(angle), angle, angle * 0.13)


func set_low_quality(enabled: bool) -> void:
    low_quality = enabled
    if is_instance_valid(_gpu_rain):
        _gpu_rain.amount = 48 if enabled else 160
    for index in _rain.size():
        _rain[index].visible = not enabled or index % 3 == 0


func get_active_particles() -> int:
    var gpu_count := _gpu_rain.amount if is_instance_valid(_gpu_rain) and _gpu_rain.emitting else 0
    return gpu_count + _rain.filter(func(item): return item.visible).size()


func get_pool_usage() -> int:
    return _set_pieces.size() + _props.size()


func _build_gpu_rain() -> void:
    _gpu_rain = GPUParticles3D.new()
    _gpu_rain.name = "RainParticles"
    _gpu_rain.amount = 160
    _gpu_rain.lifetime = 1.8
    _gpu_rain.position = Vector3(0, 10, -14)
    _gpu_rain.visibility_aabb = AABB(Vector3(-18, -14, -48), Vector3(36, 30, 58))
    var process_material := ParticleProcessMaterial.new()
    process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
    process_material.emission_box_extents = Vector3(16, 8, 30)
    process_material.direction = Vector3(0.08, -1.0, 0.18)
    process_material.spread = 4.0
    process_material.initial_velocity_min = 18.0
    process_material.initial_velocity_max = 28.0
    process_material.gravity = Vector3(0, -4, 0)
    _gpu_rain.process_material = process_material
    var streak := QuadMesh.new()
    streak.size = Vector2(0.025, 0.8)
    var rain_material := StandardMaterial3D.new()
    rain_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    rain_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    rain_material.albedo_color = Color(0.45, 0.72, 1.0, 0.5)
    rain_material.emission_enabled = true
    rain_material.emission = Color(0.15, 0.38, 0.7)
    streak.material = rain_material
    _gpu_rain.draw_pass_1 = streak
    add_child(_gpu_rain)


func _build_traffic_and_animation() -> void:
    var path := Path3D.new()
    path.name = "SkyTrafficPath"
    var curve := Curve3D.new()
    curve.add_point(Vector3(-15, 11, -35))
    curve.add_point(Vector3(0, 14, -58))
    curve.add_point(Vector3(15, 10, -32))
    curve.add_point(Vector3(-15, 11, -35))
    path.curve = curve
    add_child(path)
    _traffic_follow = PathFollow3D.new()
    _traffic_follow.loop = true
    path.add_child(_traffic_follow)
    var traffic := _box(Vector3(1.6, 0.18, 0.34), Color(0.05, 0.7, 1.0), Vector3.ZERO)
    remove_child(traffic)
    _traffic_follow.add_child(traffic)
    var beacon := _box(Vector3(0.22, 2.8, 0.22), Color(1.0, 0.03, 0.12), Vector3(0, 13, -42))
    beacon.name = "SignalBeacon"
    _animation_player = AnimationPlayer.new()
    _animation_player.root_node = NodePath("..")
    add_child(_animation_player)
    var animation := Animation.new()
    animation.length = 1.4
    animation.loop_mode = Animation.LOOP_LINEAR
    var track := animation.add_track(Animation.TYPE_VALUE)
    animation.track_set_path(track, NodePath("SignalBeacon:rotation:y"))
    animation.track_insert_key(track, 0.0, 0.0)
    animation.track_insert_key(track, 1.4, TAU)
    var library := AnimationLibrary.new()
    library.add_animation("beacon_spin", animation)
    _animation_player.add_animation_library("", library)
    _animation_player.play("beacon_spin")

func _build_city() -> void:
    for section in range(5):
        var root := Node3D.new()
        add_child(root)
        root.position.z = 20.0 - section * 42.0
        _box(Vector3(16.0, 0.35, 42.0), Color(0.022, 0.026, 0.032), Vector3(0, -0.2, 0), root, 0.04, 0.76)
        _box(Vector3(0.16, 0.025, 42.0), Color(0.08, 0.32, 0.4), Vector3(0, 0.0, 0), root, 0.15, 0.24)
        for side in [-1, 1]:
            _box(Vector3(3.7, 0.45, 42.0), Color(0.19, 0.2, 0.21), Vector3(float(side) * 9.8, 0.02, 0), root, 0.0, 0.85)
            _box(Vector3(0.3, 0.62, 42.0), Color(0.42, 0.43, 0.42), Vector3(float(side) * 8.08, 0.12, 0), root)
        for lane in [-1, 1]:
            for dash in range(7):
                _box(Vector3(0.13, 0.025, 2.7), Color(0.82, 0.79, 0.58), Vector3(float(lane) * 2.65, 0.0, -17.5 + dash * 5.8), root)
        for puddle_index in range(4):
            var puddle := _box(
                Vector3(1.4 + puddle_index * 0.22, 0.012, 2.1),
                Color(0.04, 0.16, 0.23, 0.62),
                Vector3(-5.5 + puddle_index * 3.7, 0.018, -14.0 + puddle_index * 8.4),
                root, 0.65, 0.08
            )
            puddle.rotation.y = 0.15 * puddle_index
        if section % 2 == 0:
            for stripe in range(8):
                _box(Vector3(1.25, 0.028, 0.42), Color(0.78, 0.8, 0.76), Vector3(-5.3 + stripe * 1.52, 0.025, 13.5), root, 0.05, 0.42)
        var manhole := _torus(0.72, 0.09, Color(0.18, 0.2, 0.21), Vector3(3.8, 0.03, -8.0), root)
        manhole.rotation.x = PI * 0.5
        _chunks.append(root)
    for side in [-1, 1]:
        for index in range(20):
            var building := _make_building(side, index)
            building.position.z = 18.0 - index * 10.5 + _rng.randf_range(-1.5, 1.5)
            _chunks.append(building)
    for index in range(20):
        var side := -1 if index % 2 == 0 else 1
        var prop := _make_street_prop(index % 5, side)
        prop.position.z = 15.0 - index * 9.5
        _props.append(prop)


func _make_building(side: int, index: int) -> Node3D:
    var root := Node3D.new()
    add_child(root)
    var width := _rng.randf_range(7.0, 11.5)
    var height := _rng.randf_range(13.0, 36.0)
    var depth := _rng.randf_range(8.0, 11.5)
    var colors := [Color(0.12, 0.14, 0.17), Color(0.18, 0.12, 0.12), Color(0.1, 0.13, 0.16), Color(0.17, 0.17, 0.16)]
    root.position.x = float(side) * (12.5 + width * 0.5 + _rng.randf_range(0.0, 2.5))
    _box(Vector3(width, height, depth), colors[index % colors.size()], Vector3(0, height * 0.5, 0), root, 0.05, 0.78)
    _box(Vector3(width * 0.93, 0.45, depth * 0.9), colors[index % colors.size()].lightened(0.08), Vector3(0, height + 0.2, 0), root)
    for corner_z in [-1, 1]:
        _box(Vector3(0.18, height * 0.94, 0.18), Color(0.28, 0.3, 0.32), Vector3(-float(side) * width * 0.515, height * 0.5, float(corner_z) * depth * 0.44), root, 0.45, 0.3)
    var facade_x := -float(side) * width * 0.505
    var floors := mini(8, int(height / 3.2))
    for floor_index in range(1, floors):
        for column in range(3):
            var z := -depth * 0.32 + column * depth * 0.32
            var lit := (floor_index + column + index) % 4 != 0
            var color := Color(0.86, 0.7, 0.38) if lit else Color(0.055, 0.09, 0.12)
            var window := _box(Vector3(0.055, 1.12, 1.25), color, Vector3(facade_x, 2.2 + floor_index * 3.1, z), root, 0.05, 0.24)
            if lit:
                _set_emission(window, color, 1.45)
    if index % 4 == 0:
        for level in range(2, mini(7, floors)):
            _box(Vector3(0.8, 0.11, depth * 0.58), Color(0.1, 0.11, 0.12), Vector3(facade_x - float(side) * 0.38, 1.9 + level * 3.1, 0), root, 0.7, 0.35)
    if index % 5 == 0:
        for leg_x in [-0.7, 0.7]:
            for leg_z in [-0.55, 0.55]:
                _cylinder(0.06, 2.0, Color(0.13, 0.14, 0.14), Vector3(leg_x, height + 1.0, leg_z), root, 8)
        _cylinder(1.2, 1.8, Color(0.25, 0.22, 0.19), Vector3(0, height + 2.6, 0), root, 18)
    if index % 3 == 0:
        var sign_color := Color(0.05, 0.72, 1.0) if index % 2 == 0 else Color(1.0, 0.05, 0.22)
        var sign := _box(Vector3(0.12, 2.4, 3.6), sign_color, Vector3(facade_x - float(side) * 0.12, height * 0.62, 0), root, 0.25, 0.18)
        _set_emission(sign, sign_color, 3.5)
    return root


func _make_street_prop(kind: int, side: int) -> Node3D:
    var root := Node3D.new()
    add_child(root)
    root.position.x = float(side) * 7.15
    match kind:
        0:
            _make_lamp_post(root)
        1:
            _make_car(root, Color(0.5, 0.06, 0.07), false)
            root.position.x = float(side) * 6.1
        2:
            _make_dumpster(root)
        3:
            _make_hydrant(root)
        4:
            _make_bus(root, Color(0.06, 0.34, 0.55))
            root.position.x = float(side) * 5.4
    return root


func _build_rain() -> void:
    for _index in range(72):
        var streak := _box(
            Vector3(0.018, _rng.randf_range(0.42, 0.95), 0.018),
            Color(0.55, 0.72, 0.85),
            Vector3(_rng.randf_range(-14.0, 14.0), _rng.randf_range(1.0, 19.0), _rng.randf_range(-52.0, 5.0)),
            self, 0.0, 0.22
        )
        _set_emission(streak, Color(0.28, 0.45, 0.62), 1.1)
        _rain.append(streak)


func _build_boss() -> void:
    var boss_scene: PackedScene = preload("res://scenes/green_goblin_boss.tscn")
    _boss = boss_scene.instantiate() as GreenGoblinVisual
    _boss.name = "GreenGoblin"
    add_child(_boss)
    _boss.visible = false
    _boss_shadow = _box(Vector3(5.8, 0.04, 8.4), Color(0.0, 0.0, 0.0, 0.72), Vector3(0, 0.02, -22), self, 0.0, 1.0)
    _boss_shadow.visible = false
    for _index in range(18):
        var cage_strand := _cylinder(0.045, 9.0, Color(0.78, 0.95, 1.0), Vector3.ZERO, self, 8)
        _set_emission(cage_strand, Color(0.36, 0.82, 1.0), 4.0)
        cage_strand.visible = false
        _cage.append(cage_strand)

func _spawn_piece(kind: StringName) -> void:
    var piece := Node3D.new()
    piece.name = str(kind).capitalize()
    piece.position = Vector3(player_lane * 3.0, 0.0, -48.0)
    add_child(piece)
    match kind:
        &"billboard":
            _box(Vector3(8.5, 3.8, 0.35), Color(0.7, 0.04, 0.08), Vector3(0, 4.2, 0), piece, 0.25, 0.38)
            var billboard_core := _box(Vector3(6.8, 2.1, 0.12), Color(0.03, 0.56, 0.82), Vector3(0, 4.2, 0.24), piece, 0.1, 0.18)
            _set_emission(billboard_core, Color(0.02, 0.45, 0.9), 2.4)
            for edge_x in [-4.3, 4.3]:
                _box(Vector3(0.2, 4.2, 0.55), Color(0.12, 0.13, 0.15), Vector3(edge_x, 4.2, 0), piece)
            for side in [-1, 1]:
                _cylinder(0.12, 5.0, Color(0.18, 0.19, 0.2), Vector3(float(side) * 3.5, 2.5, 0), piece, 10)
            piece.position = Vector3(3.2, 0.0, -48.0)
            piece.rotation.z = -0.35
        &"vent":
            _box(Vector3(4.6, 1.8, 3.2), Color(0.25, 0.28, 0.3), Vector3(0, 0.9, 0), piece, 0.65, 0.3)
            _box(Vector3(3.8, 0.18, 2.6), Color(0.08, 0.1, 0.12), Vector3(0, 1.85, 0), piece)
            var fan := _torus(0.92, 0.1, Color(0.08, 0.1, 0.12), Vector3(0, 1.96, 0), piece)
            fan.rotation.x = PI * 0.5
            for blade_index in range(4):
                var blade := _box(Vector3(0.15, 0.05, 1.35), Color(0.4, 0.44, 0.46), Vector3(0, 2.0, 0), piece)
                blade.rotation.y = blade_index * PI * 0.5
        &"barrier":
            _make_rubble(piece)
            _box(Vector3(8.0, 2.2, 1.0), Color(0.38, 0.34, 0.28), Vector3(0, 1.1, 0), piece, 0.05, 0.9)
            for stripe in range(7):
                var warning := _box(Vector3(0.65, 0.12, 1.06), Color(1.0, 0.56, 0.04), Vector3(-3.1 + stripe * 1.02, 1.25, 0), piece, 0.1, 0.25)
                warning.rotation.z = -0.55
        &"swing":
            _cylinder(0.22, 8.5, Color(0.24, 0.26, 0.28), Vector3(0, 4.25, 0), piece, 14)
            var anchor := _sphere(0.55, Color(0.08, 0.65, 1.0), Vector3(0, 8.4, 0), piece, 16, 10)
            _set_emission(anchor, Color(0.05, 0.55, 1.0), 5.0)
            piece.position = Vector3(-4.8, 0.0, -45.0)
        &"crane":
            _cylinder(0.18, 9.0, Color(0.45, 0.4, 0.08), Vector3(0, 4.5, 0), piece, 12)
            _box(Vector3(10.0, 0.28, 0.3), Color(0.8, 0.68, 0.08), Vector3(-3.8, 8.8, 0), piece, 0.35, 0.42)
            piece.position = Vector3(-5.5, 0.0, -49.0)
            piece.set_meta("lateral_speed", 2.2)
        &"collapse":
            _make_rubble(piece)
            for index in range(4):
                var slab := _box(Vector3(3.5, 0.45, 2.0), Color(0.3, 0.29, 0.28), Vector3(-4.5 + index * 3.0, 1.0 + index * 0.5, 0), piece, 0.05, 0.9)
                slab.rotation.z = -0.25 + index * 0.16
        &"car":
            _make_car(piece, Color(0.92, 0.55, 0.035), true)
            piece.position = Vector3(3.6, 2.4, -49.0)
            piece.set_meta("lateral_speed", -2.3)
            piece.set_meta("velocity_y", 4.8)
            piece.set_meta("gravity", -5.2)
            piece.set_meta("spin", Vector3(1.5, 2.2, -1.0))
        &"drone":
            _make_glider_raider(piece)
            piece.position = Vector3(player_lane * 2.4, 5.7, -32.0)
            piece.scale = Vector3.ONE * 1.35
            piece.set_meta("lateral_speed", -1.2 if player_lane > 0.0 else 1.2)
            piece.set_meta("wobble", 1.2)
        &"bicycle":
            _make_bicycle(piece)
            piece.position = Vector3(player_lane * 2.8, 0.95, -47.0)
            piece.set_meta("spin", Vector3(0.0, 0.8, 1.0))
            piece.set_meta("wobble", 0.8)
        &"dumpster":
            _make_dumpster(piece)
            piece.position = Vector3(player_lane * 2.7, 0.0, -48.0)
            piece.set_meta("spin", Vector3(0.2, 0.5, 0.25))
        &"scaffold":
            _make_scaffold(piece)
        &"lamp_post":
            _make_lamp_post(piece)
            piece.position = Vector3(-5.8, 0.0, -47.0)
            piece.rotation.z = -0.55
            piece.set_meta("lateral_speed", 2.0)
            piece.set_meta("spin", Vector3(0.25, 0.9, 0.8))
        &"rescue":
            _make_civilian(piece)
            piece.position = Vector3(4.7, 6.0, -45.0)
            piece.set_meta("velocity_y", -1.0)
            piece.set_meta("gravity", -0.55)
            piece.set_meta("spin", Vector3(0.0, 0.0, 0.45))
        &"traffic_light":
            _make_traffic_light(piece)
            piece.position = Vector3(-4.0, 1.5, -48.0)
            piece.set_meta("lateral_speed", 1.7)
            piece.set_meta("spin", Vector3(0.3, 0.7, 1.2))
        &"right_slash":
            for offset in [-0.65, 0.0, 0.65]:
                var slash := _beam_between(piece, Vector3(-3.6 + offset, 1.4, 0), Vector3(3.2 + offset, 7.8, 0), 0.09, Color(1.0, 0.05, 0.1))
                _set_emission(slash, Color(1.0, 0.03, 0.08), 7.0)
            piece.position = Vector3(2.6, 0.0, -35.0)
            piece.set_meta("lateral_speed", -2.8)
            piece.set_meta("speed_scale", 1.65)
            piece.set_meta("life", 0.85)
        &"overhead":
            var overhead := _beam_between(piece, Vector3(-1.8, 8.8, 0), Vector3(1.8, 0.8, 0), 0.13, Color(1.0, 0.58, 0.08))
            _set_emission(overhead, Color(1.0, 0.4, 0.04), 8.0)
            var overhead_core := _beam_between(piece, Vector3(-1.8, 8.8, 0.08), Vector3(1.8, 0.8, 0.08), 0.045, Color.WHITE)
            _set_emission(overhead_core, Color(1.0, 0.9, 0.62), 10.0)
            piece.position = Vector3(0.0, 0.0, -34.0)
            piece.set_meta("speed_scale", 1.55)
            piece.set_meta("life", 0.85)
        &"energy":
            var blast := _sphere(0.42, Color(0.3, 1.0, 0.12), Vector3.ZERO, piece, 24, 16)
            _set_emission(blast, Color(0.2, 1.0, 0.08), 9.0)
            var blast_ring := _torus(0.68, 0.06, Color(0.7, 1.0, 0.28), Vector3.ZERO, piece)
            blast_ring.rotation.x = PI * 0.5
            _set_emission(blast_ring, Color(0.4, 1.0, 0.12), 8.0)
            piece.position = Vector3(0.0, 5.5, -34.0)
            piece.set_meta("speed_scale", 1.75)
            piece.set_meta("life", 0.48)
        &"counter":
            var lock_ring := _torus(2.1, 0.1, Color(0.08, 0.78, 1.0), Vector3.ZERO, piece)
            lock_ring.rotation.x = PI * 0.5
            _set_emission(lock_ring, Color(0.05, 0.72, 1.0), 7.0)
            var lock_core := _sphere(0.28, Color.WHITE, Vector3.ZERO, piece, 16, 10)
            _set_emission(lock_core, Color(0.25, 0.88, 1.0), 8.0)
            piece.position = Vector3(0.0, 5.7, -17.2)
            piece.set_meta("speed_scale", 0.0)
            piece.set_meta("life", 2.8)
        &"shockwave", &"ground_wave":
            _make_shockwave(piece, kind == &"ground_wave")
            piece.position.y = 0.2 if kind == &"ground_wave" else 2.8
        &"rubble":
            _make_rubble(piece)
        &"debris":
            _make_debris(piece)
            piece.position = Vector3(2.5, 5.7, -39.0)
            piece.set_meta("lateral_speed", -1.0)
            piece.set_meta("spin", Vector3(1.8, 1.2, 2.5))
    _set_pieces.append(piece)


func _make_car(parent: Node3D, paint: Color, airborne: bool) -> void:
    _box(Vector3(3.7, 0.75, 1.85), paint, Vector3(0, 0.72, 0), parent, 0.58, 0.3)
    _box(Vector3(2.1, 0.82, 1.68), paint.darkened(0.08), Vector3(-0.25, 1.42, 0), parent, 0.5, 0.26)
    _box(Vector3(0.88, 0.48, 1.7), Color(0.035, 0.09, 0.13), Vector3(-0.75, 1.47, 0), parent, 0.15, 0.12)
    _box(Vector3(0.76, 0.48, 1.7), Color(0.035, 0.09, 0.13), Vector3(0.38, 1.47, 0), parent, 0.15, 0.12)
    for x in [-1.25, 1.2]:
        for z in [-0.84, 0.84]:
            var wheel := _cylinder(0.38, 0.22, Color(0.018, 0.018, 0.02), Vector3(x, 0.48, z), parent, 16)
            wheel.rotation.x = PI * 0.5
    for z in [-0.72, 0.72]:
        var lamp_color := Color(1.0, 0.12, 0.04) if airborne else Color(1.0, 0.88, 0.58)
        var lamp := _sphere(0.12, lamp_color, Vector3(1.88, 0.82, z), parent, 10, 6)
        _set_emission(lamp, lamp_color, 4.0)


func _make_bus(parent: Node3D, paint: Color) -> void:
    _box(Vector3(6.8, 2.5, 2.35), paint, Vector3(0, 1.55, 0), parent, 0.45, 0.34)
    _box(Vector3(6.25, 0.38, 2.1), paint.lightened(0.12), Vector3(-0.1, 3.0, 0), parent, 0.34, 0.28)
    for window_index in range(5):
        for side in [-1, 1]:
            var window := _box(Vector3(0.82, 0.72, 0.045), Color(0.025, 0.12, 0.18), Vector3(-2.35 + window_index * 1.18, 2.12, float(side) * 1.19), parent, 0.1, 0.08)
            _set_emission(window, Color(0.05, 0.2, 0.28), 0.7)
    _box(Vector3(0.08, 1.35, 1.72), Color(0.025, 0.11, 0.16), Vector3(3.42, 2.0, 0), parent, 0.1, 0.08)
    for x in [-2.35, 2.25]:
        for z in [-1.13, 1.13]:
            var wheel := _cylinder(0.48, 0.24, Color(0.018, 0.02, 0.024), Vector3(x, 0.52, z), parent, 18)
            wheel.rotation.x = PI * 0.5
    for z in [-0.78, 0.78]:
        var headlight := _sphere(0.14, Color(0.95, 0.86, 0.55), Vector3(3.45, 1.05, z), parent, 10, 6)
        _set_emission(headlight, Color(1.0, 0.78, 0.35), 4.0)


func _make_glider_raider(parent: Node3D) -> void:
    var glider := _box(Vector3(4.8, 0.18, 1.25), Color(0.08, 0.13, 0.17), Vector3(0, -0.55, 0), parent, 0.7, 0.2)
    glider.rotation.z = 0.08
    for side in [-1, 1]:
        var wing := _box(Vector3(2.1, 0.1, 1.65), Color(0.12, 0.48, 0.55), Vector3(float(side) * 2.05, -0.48, 0), parent, 0.68, 0.18)
        wing.rotation.z = -float(side) * 0.22
        var thruster := _sphere(0.22, Color(0.08, 0.7, 1.0), Vector3(float(side) * 2.25, -0.58, -0.75), parent, 12, 7)
        _set_emission(thruster, Color(0.02, 0.62, 1.0), 6.0)
    _cylinder(0.42, 1.5, Color(0.14, 0.18, 0.2), Vector3(0, 0.45, 0), parent, 14)
    var helmet := _sphere(0.38, Color(0.06, 0.075, 0.09), Vector3(0, 1.48, 0), parent, 16, 10)
    helmet.scale = Vector3(0.9, 1.05, 0.86)
    var visor := _box(Vector3(0.52, 0.12, 0.48), Color(1.0, 0.05, 0.18), Vector3(0, 1.52, 0.32), parent, 0.2, 0.12)
    _set_emission(visor, Color(1.0, 0.02, 0.12), 5.0)
    for side in [-1, 1]:
        var arm := _cylinder(0.11, 1.3, Color(0.12, 0.15, 0.18), Vector3(float(side) * 0.7, 0.48, 0), parent, 10)
        arm.rotation.z = float(side) * 0.9


func _make_drone(parent: Node3D) -> void:
    _sphere(0.62, Color(0.12, 0.15, 0.18), Vector3.ZERO, parent, 18, 12)
    for x in [-1.0, 1.0]:
        for z in [-0.65, 0.65]:
            _box(Vector3(1.0, 0.08, 0.08), Color(0.2, 0.22, 0.24), Vector3(x * 0.5, 0.0, z), parent)
            _cylinder(0.48, 0.035, Color(0.05, 0.06, 0.07), Vector3(x, 0.08, z), parent, 16)
    var lens := _sphere(0.19, Color(0.03, 0.55, 0.9), Vector3(0, -0.18, 0.56), parent, 12, 8)
    _set_emission(lens, Color(0.02, 0.55, 1.0), 5.0)


func _make_bicycle(parent: Node3D) -> void:
    for x in [-0.85, 0.85]:
        var wheel := _torus(0.52, 0.055, Color(0.04, 0.045, 0.05), Vector3(x, 0.55, 0), parent)
        wheel.rotation.y = PI * 0.5
    _beam_between(parent, Vector3(-0.85, 0.55, 0), Vector3(0, 1.25, 0), 0.055, Color(0.72, 0.06, 0.05))
    _beam_between(parent, Vector3(0, 1.25, 0), Vector3(0.85, 0.55, 0), 0.055, Color(0.72, 0.06, 0.05))
    _beam_between(parent, Vector3(-0.85, 0.55, 0), Vector3(0.35, 0.55, 0), 0.055, Color(0.72, 0.06, 0.05))
    _box(Vector3(0.5, 0.08, 0.18), Color(0.05, 0.05, 0.05), Vector3(-0.05, 1.36, 0), parent)


func _make_dumpster(parent: Node3D) -> void:
    _box(Vector3(3.0, 1.65, 1.65), Color(0.08, 0.28, 0.22), Vector3(0, 0.88, 0), parent, 0.25, 0.68)
    for side in [-1, 1]:
        var lid := _box(Vector3(1.45, 0.13, 1.82), Color(0.04, 0.14, 0.12), Vector3(float(side) * 0.75, 1.78, 0), parent)
        lid.rotation.z = -float(side) * 0.08


func _make_lamp_post(parent: Node3D) -> void:
    _cylinder(0.1, 5.7, Color(0.1, 0.11, 0.12), Vector3(0, 2.85, 0), parent, 10)
    var arm := _box(Vector3(1.45, 0.11, 0.11), Color(0.1, 0.11, 0.12), Vector3(-0.62, 5.55, 0), parent)
    arm.rotation.z = -0.12
    var light := _sphere(0.25, Color(1.0, 0.82, 0.48), Vector3(-1.3, 5.38, 0), parent, 12, 8)
    _set_emission(light, Color(1.0, 0.76, 0.35), 4.0)


func _make_hydrant(parent: Node3D) -> void:
    _cylinder(0.28, 0.75, Color(0.72, 0.04, 0.035), Vector3(0, 0.38, 0), parent, 12)
    _sphere(0.31, Color(0.75, 0.05, 0.04), Vector3(0, 0.8, 0), parent, 12, 8)
    var cap := _cylinder(0.16, 0.4, Color(0.62, 0.04, 0.03), Vector3(0.3, 0.48, 0), parent, 10)
    cap.rotation.z = PI * 0.5


func _make_scaffold(parent: Node3D) -> void:
    for x in [-4.2, 4.2]:
        _cylinder(0.08, 5.8, Color(0.3, 0.31, 0.3), Vector3(x, 2.9, 0), parent, 8)
    _box(Vector3(9.0, 0.25, 1.25), Color(0.27, 0.2, 0.12), Vector3(0, 5.1, 0), parent)
    for x in range(-4, 5, 2):
        _beam_between(parent, Vector3(x, 0.2, 0), Vector3(x + 1.5, 5.0, 0), 0.055, Color(0.3, 0.31, 0.3))


func _make_civilian(parent: Node3D) -> void:
    _sphere(0.28, Color(0.55, 0.32, 0.2), Vector3(0, 2.05, 0), parent, 14, 9)
    _cylinder(0.42, 1.3, Color(0.86, 0.42, 0.08), Vector3(0, 1.2, 0), parent, 12)
    for side in [-1, 1]:
        var arm := _cylinder(0.11, 1.25, Color(0.3, 0.45, 0.7), Vector3(float(side) * 0.62, 1.35, 0), parent, 8)
        arm.rotation.z = float(side) * 0.9
        var leg := _cylinder(0.13, 1.2, Color(0.07, 0.09, 0.13), Vector3(float(side) * 0.2, 0.15, 0), parent, 8)
        leg.rotation.z = float(side) * 0.15


func _make_traffic_light(parent: Node3D) -> void:
    _box(Vector3(0.7, 2.2, 0.65), Color(0.07, 0.075, 0.075), Vector3(0, 1.1, 0), parent)
    var colors := [Color(0.9, 0.03, 0.03), Color(0.92, 0.68, 0.03), Color(0.02, 0.8, 0.2)]
    for index in range(3):
        var light := _sphere(0.21, colors[index], Vector3(0, 1.72 - index * 0.62, 0.35), parent, 12, 8)
        _set_emission(light, colors[index], 3.0 if index == 0 else 0.5)


func _make_shockwave(parent: Node3D, ground: bool) -> void:
    for index in range(3):
        var ring := _torus(4.0 + index * 1.5, 0.08, Color(0.2, 0.75, 1.0, 0.48), Vector3.ZERO, parent)
        ring.rotation.x = PI * 0.5 if not ground else 0.0
        _set_emission(ring, Color(0.12, 0.65, 1.0), 3.5)


func _make_rubble(parent: Node3D) -> void:
    for _index in range(12):
        var chunk := _box(Vector3(_rng.randf_range(0.7, 1.8), _rng.randf_range(0.45, 1.2), _rng.randf_range(0.8, 1.7)), Color(0.22, 0.21, 0.2), Vector3(_rng.randf_range(-4.4, 4.4), _rng.randf_range(0.25, 0.8), _rng.randf_range(-2.2, 2.2)), parent, 0.05, 0.9)
        chunk.rotation = Vector3(_rng.randf(), _rng.randf(), _rng.randf())


func _make_debris(parent: Node3D) -> void:
    _box(Vector3(3.8, 0.45, 1.1), Color(0.28, 0.29, 0.3), Vector3.ZERO, parent, 0.52, 0.5)
    var beam := _cylinder(0.2, 4.8, Color(0.17, 0.18, 0.19), Vector3.ZERO, parent, 10)
    beam.rotation.z = PI * 0.5
    for index in range(5):
        _sphere(0.18 + index * 0.04, Color(0.32, 0.28, 0.24), Vector3(-1.7 + index * 0.75, 0.5 + sin(index) * 0.35, 0), parent, 10, 7)


func _pulse_boss(kind: StringName) -> void:
    if not is_instance_valid(_boss):
        return
    _boss.play_action(kind)
    _boss_reaction_time = 0.35
    _boss_reaction_offset = Vector3.ZERO
    _boss_reaction_rotation = Vector3.ZERO
    if kind == &"energy":
        _boss_reaction_offset = Vector3(0, 0, 1.2)
    elif kind == &"right_slash":
        _boss_reaction_rotation.z = -0.32
    elif kind == &"overhead":
        _boss_reaction_rotation.x = -0.22
    elif kind == &"counter":
        _boss_reaction_offset = Vector3(0, 0.5, -0.8)
    elif kind == &"debris":
        _boss_reaction_rotation.y = 0.35
    elif kind == &"ground_wave":
        _boss_reaction_offset = Vector3(0, -0.6, 0)


func _beam_between(parent: Node3D, start: Vector3, finish: Vector3, radius: float, color: Color) -> MeshInstance3D:
    var beam := _cylinder(radius, start.distance_to(finish), color, (start + finish) * 0.5, parent, 8)
    beam.quaternion = Quaternion(Vector3.UP, (finish - start).normalized())
    return beam


func _box(size: Vector3, color: Color, position_: Vector3, parent: Node = null, metallic := 0.32, roughness := 0.58) -> MeshInstance3D:
    var mesh := BoxMesh.new()
    mesh.size = size
    return _mesh_instance(mesh, color, position_, parent, metallic, roughness)


func _sphere(radius: float, color: Color, position_: Vector3, parent: Node = null, radial_segments := 18, rings := 12, override_material: Material = null) -> MeshInstance3D:
    var mesh := SphereMesh.new()
    mesh.radius = radius
    mesh.height = radius * 2.0
    mesh.radial_segments = radial_segments
    mesh.rings = rings
    return _mesh_instance(mesh, color, position_, parent, 0.25, 0.42, override_material)


func _cylinder(radius: float, height: float, color: Color, position_: Vector3, parent: Node = null, sides := 12, override_material: Material = null) -> MeshInstance3D:
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = height
    mesh.radial_segments = sides
    return _mesh_instance(mesh, color, position_, parent, 0.38, 0.46, override_material)


func _torus(radius: float, tube: float, color: Color, position_: Vector3, parent: Node = null) -> MeshInstance3D:
    var mesh := TorusMesh.new()
    mesh.inner_radius = maxf(0.01, radius - tube)
    mesh.outer_radius = radius
    mesh.rings = 24
    mesh.ring_segments = 8
    return _mesh_instance(mesh, color, position_, parent, 0.3, 0.4)


func _mesh_instance(mesh: PrimitiveMesh, color: Color, position_: Vector3, parent: Node, metallic: float, roughness: float, override_material: Material = null) -> MeshInstance3D:
    var instance := MeshInstance3D.new()
    instance.mesh = mesh
    if override_material != null:
        instance.material_override = override_material
    else:
        var material := StandardMaterial3D.new()
        material.albedo_color = color
        material.metallic = metallic
        material.roughness = roughness
        if color.a < 1.0:
            material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        instance.material_override = material
    instance.position = position_
    if parent == null:
        parent = self
    parent.add_child(instance)
    return instance


func _set_emission(instance: MeshInstance3D, color: Color, energy: float) -> void:
    var material := instance.material_override as StandardMaterial3D
    if material == null:
        return
    material.emission_enabled = true
    material.emission = color
    material.emission_energy_multiplier = energy
