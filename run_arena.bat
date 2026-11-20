@echo off
rem Play the Phase C grove arena with the T-025 capture rig attached (probe CSV +
rem a PNG at each death). No editor needed.
rem Usage: run_arena.bat [extra Godot args]
set GODOT_EXE=C:\Users\My Lenovo\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe
"%GODOT_EXE%" --path "%~dp0." --resolution 1280x720 res://scenes/phase_c/play_arena.tscn %*