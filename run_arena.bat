@echo off
rem Play the Phase C grove arena (3 waves + mini-boss + reward) without the editor.
rem Usage: run_arena.bat [extra Godot args]
set GODOT_EXE=C:\Users\My Lenovo\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe
"%GODOT_EXE%" --path "%~dp0." --resolution 1280x720 res://scenes/phase_c/grove_arena.tscn %*