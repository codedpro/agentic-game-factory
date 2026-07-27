extends Control
## App shell: screen routing, Android back button, resize handling.

const SCREENS := {
	"menu": "res://scripts/screens/menu_screen.gd",
	"game": "res://scripts/screens/game_screen.gd",
	"settings": "res://scripts/screens/settings_screen.gd",
	"records": "res://scripts/screens/records_screen.gd",
	"shop": "res://scripts/screens/shop_screen.gd",
	"fal": "res://scripts/screens/fal_screen.gd",
	"board": "res://scripts/screens/board_screen.gd",
	"tasks": "res://scripts/screens/tasks_screen.gd",
	"account": "res://scripts/screens/account_screen.gd",
}

var current_name := ""
var current: Control
var bg: ColorRect


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	bg = ColorRect.new()
	bg.color = UI.bg_color()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	get_viewport().size_changed.connect(_on_resize)
	get_tree().set_auto_accept_quit(false)
	Notify.on_app_open()
	_grant_daily_login_gift()
	show_screen("menu")
	if "--autoplay" in OS.get_cmdline_user_args():
		show_screen("game", {"autoplay": true})
		current.start_autoplay()


## Repaint chrome that lives outside the screens (theme purchases change it).
func refresh_theme() -> void:
	if bg and is_instance_valid(bg):
		bg.color = UI.bg_color()


func show_screen(name: String, data := {}) -> void:
	refresh_theme()
	if current and is_instance_valid(current):
		current.queue_free()
	current_name = name
	current = Control.new()
	current.set_anchors_preset(Control.PRESET_FULL_RECT)
	current.set_script(load(SCREENS[name]))
	current.set("shell", self)
	current.set("data", data)
	add_child(current)


func _on_resize() -> void:
	if current and is_instance_valid(current) and current.has_method("relayout"):
		current.relayout()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		# Screens get first refusal so an open modal closes instead of the whole screen.
		if current and is_instance_valid(current) and current.has_method("on_back"):
			if current.on_back():
				return
		if current_name == "menu":
			Store.flush()
			get_tree().quit()
		else:
			show_screen("menu")
	elif what == NOTIFICATION_APPLICATION_PAUSED:
		# Backgrounding (an incoming call, a notification pull, Home) must PERSIST, never
		# quit — quitting here destroyed the run and burned the day's single attempt.
		Store.flush()
		Store.save()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		Store.flush()
		Store.save()
		get_tree().quit()


## The فال is a gift for showing up, not a prize for winning: opening the app on a new day
## earns today's verse, which the player then reveals through the نیت ceremony.
func _grant_daily_login_gift() -> void:
	var key := Time.get_date_string_from_system().replace("-", "")
	if Store.fal_last_date == key:
		return
	if Fal.grant_daily(key).is_empty():
		return
	Store.add_coins(250)         # a small daily-login bonus alongside it
