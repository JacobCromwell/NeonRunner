class_name SaveService
extends RefCounted
## Reads and writes the Profile as JSON in user://. Writes go to a temporary file first and keep
## the previous save as a backup, so a crash mid-write never loses progress.
## DESIGN-TBD: cloud save (Steam Cloud / platform saves) will sync this file through Platform.

const PATH: String = "user://profile.json"


static func load_profile(path: String = PATH) -> Profile:
	for candidate: String in [path, path + ".bak"]:
		if not FileAccess.file_exists(candidate):
			continue
		var json := JSON.new()
		if json.parse(FileAccess.get_file_as_string(candidate)) == OK and typeof(json.data) == TYPE_DICTIONARY:
			return Profile.from_dict(json.data)
		push_warning("SaveService: %s is unreadable; trying the backup" % candidate)
	return Profile.new()


static func save_profile(profile: Profile, path: String = PATH) -> bool:
	var tmp: String = path + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		push_warning("SaveService: can't write %s (%s)" % [tmp, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(JSON.stringify(profile.to_dict(), "\t"))
	file.close()
	var dir := DirAccess.open(path.get_base_dir())
	if dir == null:
		return false
	if FileAccess.file_exists(path):
		dir.rename(path.get_file(), path.get_file() + ".bak")
	return dir.rename(tmp.get_file(), path.get_file()) == OK


static func delete_save(path: String = PATH) -> void:
	for f: String in [path, path + ".bak", path + ".tmp"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(f)
