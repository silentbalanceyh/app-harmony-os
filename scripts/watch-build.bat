@echo off
setlocal EnableDelayedExpansion
echo [WARN]  watch-build.bat uses polling because fswatch/inotifywait are Unix tools.
echo Usage: scripts\watch-build.bat --app app-name [--no-restart]
echo [WARN]  Start from Git Bash/WSL with scripts/watch-build.sh for full watch behavior.
exit /b 0
