class_name CafePreferences
extends RefCounted

static var volume := 0.8
static var sensitivity := 1.0
static var fullscreen := false
static var companion := "sabri"
static var cast := "Dayılar"
static var cloth := "Bordo"
static var venue := "KIRAATHANE"
static var table_mode := "4 KİŞİ"
static var tile_speed := "NORMAL"

static func restore() -> void:
	var config := ConfigFile.new()
	if config.load("user://coffeehouse.cfg") == OK:
		volume = clampf(float(config.get_value("settings","volume",0.8)),0.0,1.0)
		sensitivity = clampf(float(config.get_value("settings","sensitivity",1.0)),0.4,2.0)
		fullscreen = bool(config.get_value("settings","fullscreen",false))
		companion = str(config.get_value("table","companion","sabri"))
		cast = str(config.get_value("table","cast","Dayılar"))
		cloth = str(config.get_value("table","cloth","Bordo"))
		venue = str(config.get_value("table","venue","KIRAATHANE"))
		table_mode = str(config.get_value("table","table_mode","4 KİŞİ"))
		tile_speed = str(config.get_value("table","tile_speed","NORMAL"))
	if not companion in MascotCharacter.KINDS and not companion in CafePatron.KINDS:
		companion = "sabri"
	apply()

static func apply() -> void:
	AudioServer.set_bus_volume_db(0,linear_to_db(maxf(volume,0.001)))
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)

static func save() -> void:
	var config := ConfigFile.new()
	config.set_value("settings","volume",volume)
	config.set_value("settings","sensitivity",sensitivity)
	config.set_value("settings","fullscreen",fullscreen)
	config.set_value("table","companion",companion)
	config.set_value("table","cast",cast)
	config.set_value("table","cloth",cloth)
	config.set_value("table","venue",venue)
	config.set_value("table","table_mode",table_mode)
	config.set_value("table","tile_speed",tile_speed)
	config.save("user://coffeehouse.cfg")
