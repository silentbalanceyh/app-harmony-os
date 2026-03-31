@echo off
setlocal EnableDelayedExpansion

rem Build current app in debug mode
rem Usage: dev-build.bat

call "%~dp0scripts\common.bat" :build_only