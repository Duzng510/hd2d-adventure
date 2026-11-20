class_name CombatLog
extends RefCounted

var path: String = ""

var _file: FileAccess


func open(log_path: String) -> void:
	path = log_path
	_file = FileAccess.open(path, FileAccess.WRITE)
	if _file == null:
		push_warning("CombatLog: cannot open %s" % path)
		return
	_file.store_line("frame,entity,event,attack_id,target_id,value")


func event(sim_frame: int, entity: StringName, event_name: StringName, attack_id: int = 0, target_id: int = 0, value: int = 0) -> void:
	if _file == null:
		return
	var line := "%d,%s,%s,%d,%d,%d" % [sim_frame, entity, event_name, attack_id, target_id, value]
	_file.store_line(line)
	_file.flush()
	print(line)


func close() -> void:
	if _file != null:
		_file.close()
		_file = null
