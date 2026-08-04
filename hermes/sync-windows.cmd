@echo off
setlocal
cd /d C:\Users\wasi\hermes-dotfiles-windows
where bash >nul 2>&1
if errorlevel 1 (
  echo Git Bash wurde nicht gefunden.
  pause
  exit /b 1
)
bash hermes/sync-windows.sh
if errorlevel 1 (
  echo Synchronisierung fehlgeschlagen.
  pause
  exit /b 1
)
pause
