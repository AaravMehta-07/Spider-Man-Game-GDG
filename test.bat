@echo off
cd /d "%~dp0"
.venv\Scripts\python.exe -m pytest && .venv\Scripts\python.exe -m ruff check .