@tool
extends EditorPlugin
## Ships the Myket billing AAR — but ONLY into the Myket export preset.
##
## A Godot 4 v2 export plugin otherwise contributes to every Android export, which would put
## Myket's billing permission into the Cafe Bazaar APK (and Bazaar rejects that). The
## per-preset "Plugins" checkbox only governs the deprecated v1 system, so the gate lives here.

var export_plugin: MyketExportPlugin


func _enter_tree() -> void:
	export_plugin = MyketExportPlugin.new()
	add_export_plugin(export_plugin)


func _exit_tree() -> void:
	if export_plugin:
		remove_export_plugin(export_plugin)
	export_plugin = null


class MyketExportPlugin extends EditorExportPlugin:
	func _get_name() -> String:
		return "GodotMyketBilling"

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	## True only for the Myket store build. Godot 4.7's EditorExportPreset exposes no
	## name getter, so the store is selected by GF_STORE, which pipeline/build_stores.sh
	## always sets (and which build_stores.sh then verifies by inspecting the built APK).
	func _is_myket_build() -> bool:
		return OS.get_environment("GF_STORE") == "myket"

	func _get_android_libraries(platform, debug: bool) -> PackedStringArray:
		if not _is_myket_build():
			return PackedStringArray()
		return PackedStringArray([
			"myket/bin/GodotMyketBilling-debug.aar" if debug
			else "myket/bin/GodotMyketBilling-release.aar"])

	func _get_android_dependencies(platform, debug: bool) -> PackedStringArray:
		# Self-contained on purpose: no third-party billing library is pulled in.
		return PackedStringArray()
