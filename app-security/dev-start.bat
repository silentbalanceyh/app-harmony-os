@echo off
setlocal EnableDelayedExpansion

rem Start current app in development mode (build + install + launch)
rem Usage: dev-start.bat

call "%~dp0scripts\common.bat" :start_dev