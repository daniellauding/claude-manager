@echo off
REM Claude Manager for Windows
REM Launches the system tray app to manage Claude CLI instances

powershell -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0claude-manager.ps1"
