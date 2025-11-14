@echo off
REM Test all routes for FlaskServer_v2
REM Usage: test_all_routes.bat [--live]

echo ========================================
echo FlaskServer_v2 Route Testing
echo ========================================
echo.

REM Check if server is running
echo Checking if server is running on http://127.0.0.1:5000...
curl -s http://127.0.0.1:5000/health >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Server is not running!
    echo Please start the server with: python main.py
    pause
    exit /b 1
)
echo Server is running!
echo.

REM Run Python test script
echo Running test suite...
echo.

if "%1"=="--live" (
    echo Running in LIVE mode (requires API key)
    python scripts\test_server.py --live
) else (
    echo Running in MOCK mode (no API key required)
    python scripts\test_server.py
)

echo.
echo ========================================
echo Testing complete!
echo ========================================
pause
