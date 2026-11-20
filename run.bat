@echo off
rem Run the game (main scene) directly, without opening the Godot editor.
rem Usage: run.bat [extra Godot args]   e.g.  run.bat --resolution 1920x1080
set GODOT_EXE=C:\Users\My Lenovo\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe
"%GODOT_EXE%" --path "%~dp0." --resolution 1280x720 %*