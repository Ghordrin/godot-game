extends Node
const LOG_PATH: String = "user://performance_debug_log.txt"

@export var enabled: bool = true
@export var print_to_console: bool = false

## Log frames slower than this.
## 16.67 ms = 60 FPS
## 33.33 ms = 30 FPS
@export var spike_threshold_ms: float = 24.0

## Regular sample interval even when there are no spikes.
@export var sample_interval_seconds: float = 2.0

var _file: FileAccess = null
var _start_time_msec: int = 0
var _sample_timer: float = 0.0


func _ready() -> void:
	_start_time_msec = Time.get_ticks_msec()
	_clear_log()
	_log_line("=== PERFORMANCE SESSION STARTED ===")
	_log_line("Log path: %s" % ProjectSettings.globalize_path(LOG_PATH))


func _exit_tree() -> void:
	if _file != null:
		_file.flush()
		_file.close()
		_file = null


func _process(delta: float) -> void:
	if not enabled:
		return

	var frame_ms: float = delta * 1000.0

	if frame_ms >= spike_threshold_ms:
		_log_sample("FRAME_SPIKE", frame_ms)
		return

	_sample_timer -= delta

	if _sample_timer <= 0.0:
		_sample_timer = sample_interval_seconds
		_log_sample("SAMPLE", frame_ms)


func _log_sample(reason: String, frame_ms: float) -> void:
	var enemy_count: int = get_tree().get_nodes_in_group("enemies").size()
	var projectile_count: int = get_tree().get_nodes_in_group("projectiles").size()
	var gold_count: int = get_tree().get_nodes_in_group("gold_pickups").size()
	var powerup_count: int = get_tree().get_nodes_in_group("powerup_pickups").size()
	var damage_number_count: int = get_tree().get_nodes_in_group("damage_numbers").size()

	var death_queue_pending: int = _get_pending_count("/root/DeathQueue")
	var gold_queue_pending: int = _get_pending_count("/root/GoldDropManager")

	_log_line(
		"%s frame_ms=%.2f fps=%d enemies=%d projectiles=%d damage_numbers=%d gold_pickups=%d powerup_pickups=%d death_queue_pending=%d gold_queue_pending=%d"
		% [
			reason,
			frame_ms,
			Engine.get_frames_per_second(),
			enemy_count,
			projectile_count,
			damage_number_count,
			gold_count,
			powerup_count,
			death_queue_pending,
			gold_queue_pending,
		]
	)


func _get_pending_count(path: String) -> int:
	var node := get_node_or_null(path)

	if node == null:
		return -1

	if node.has_method("get_pending_count"):
		return int(node.get_pending_count())

	return -1


func _clear_log() -> void:
	if _file != null:
		_file.close()
		_file = null

	_file = FileAccess.open(LOG_PATH, FileAccess.WRITE)

	if _file == null:
		push_warning("PerformanceDebugMonitor: Could not open log file at %s" % LOG_PATH)


func _log_line(message: String) -> void:
	if _file == null:
		_file = FileAccess.open(LOG_PATH, FileAccess.READ_WRITE)

		if _file == null:
			return

		_file.seek_end()

	var elapsed: float = float(Time.get_ticks_msec() - _start_time_msec) / 1000.0
	var line := "[%08.3f] %s" % [elapsed, message]

	_file.store_line(line)
	_file.flush()

	if print_to_console:
		print(line)
