@echo off
rem Oyunu baslatir. Cift tikla ya da terminalde: .\oyna.cmd
set "GODOT=C:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe"
if not exist "%GODOT%" set "GODOT=godot"
"%GODOT%" --path "%~dp0." %*
