extends Control
## App shell: screen routing, Android back button, resize handling.

const SCREENS := {
	"menu": "res://scripts/screens/menu_screen.gd",
	"game": "res://scripts/screens/game_screen.gd",
	"settings": "res://scripts/screens/settings_screen.gd",
	"records": "res://scripts/screens/records_screen.gd",
	"shop": "res://scripts/screens/shop_screen.gd",
	"masal": "res://scripts/screens/masal_screen.gd",
	"board": "res://scripts/screens/board_screen.gd",
	"tasks": "res://scripts/screens/tasks_screen.gd",
	"account": "res://scripts/screens/account_screen.gd",
}

var current_name := ""
var current: Control
var bg: ColorRect


## Boot order is a store-compliance matter, not a style choice: Myket rejected a build
## that showed only the navy clear colour on Android 12/14 because startup did platform
## work (exact alarms, permission dialogs) BEFORE any UI existed, and a failure there
## aborted _ready() with nothing on screen. The menu is therefore built first and every
## platform side-effect is deferred to a later frame (LESSONS L71).
func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	bg = ColorRect.new()
	bg.color = UI.bg_color()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	get_viewport().size_changed.connect(_on_resize)
	get_tree().set_auto_accept_quit(false)
	if "--autoplay" in OS.get_cmdline_user_args():
		show_screen("game", {"autoplay": true})
		current.start_autoplay()
		return
	show_screen("menu")          # playable UI exists before anything can fail
	_post_boot.call_deferred()


## Everything that touches the platform or persistence, run one frame AFTER the menu is
## on screen. Each step is independent: one failing must never blank the app.
func _post_boot() -> void:
	_grant_daily_login_gift()
	Notify.on_app_open()
	if current and is_instance_valid(current) and current.has_method("relayout"):
		current.relayout()       # reflect any coins the login gift just granted


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


## Unlike the fal (a gift for showing up), the daily مثل is EARNED by finishing the
## daily challenge — here showing up on a new day pays only a small coin bonus.
func _grant_daily_login_gift() -> void:
	var key := Time.get_date_string_from_system().replace("-", "")
	if Store.login_gift_day == key:
		return
	Store.login_gift_day = key
	Store.add_coins(250)
