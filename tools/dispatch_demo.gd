extends Node
var game: Node
var capture_dir := "user://dispatch_frames"
func _ready() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--capture="):
   capture_dir = arg.trim_prefix("--capture=")
 DirAccess.make_dir_recursive_absolute(capture_dir)
 game = load("res://scenes/main.tscn").instantiate()
 add_child(game)
 game.start_level(2)
 await get_tree().create_timer(1.5).timeout
 game.hud.clear_overlay()
 var solution: Array = game.levels[2]["solution"]
 for i in 7:
  game._on_tap(int(solution[i]))
  await get_tree().create_timer(0.48).timeout
 await get_tree().create_timer(0.7).timeout
 await _snap(0)
 game._on_tap(int(solution[7]))
 for i in range(1, 39):
  await get_tree().create_timer(0.09).timeout
  await _snap(i)
 print("DISPATCH_DEMO frames=39 state=", game.state)
 get_tree().quit()
func _snap(index: int) -> void:
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png(capture_dir.path_join("frame_%02d.png" % index))
