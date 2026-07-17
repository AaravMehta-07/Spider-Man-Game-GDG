@echo off
cd /d "%~dp0"
.venv\Scripts\python.exe main.py %*
if errorlevel 1 (
  echo.
  echo WEB//PROTOCOL could not start. Read the error above.
  pause
)
