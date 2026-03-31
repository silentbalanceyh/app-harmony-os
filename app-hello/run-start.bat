@echo off
setlocal EnableDelayedExpansion

rem Start current app in release mode
rem Usage: run-start.bat

call "%~dp0scripts\common.bat" :start_release