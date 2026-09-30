@echo off
echo ========================================================
echo Adding Windows Firewall Inbound Rule for Port 5000...
echo ========================================================
netsh advfirewall firewall add rule name="Alpha X Backend 5000" dir=in action=allow protocol=TCP localport=5000
echo.
if %errorlevel% == 0 (
    echo ========================================================
    echo [SUCCESS] Port 5000 is now OPEN for Alpha X Gym!
    echo Your iPhone / Android phone can now reach the server.
    echo ========================================================
) else (
    echo ========================================================
    echo [ERROR] Administrative privileges required.
    echo Please right-click this file and choose "Run as administrator".
    echo ========================================================
)
echo.
pause
