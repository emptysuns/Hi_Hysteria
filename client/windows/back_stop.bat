@echo off
echo Start Clear! 
REG add "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyEnable /t REG_DWORD /d 0 /f
REG add "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyServer /d "" /f
REG add "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyOverride /t REG_SZ /d "" /f
REG ADD "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings" /v AutoDetect /t REG_DWORD /f /D 1
for /f "tokens=5 delims= " %%i in ('netstat -ano ^| findstr "127.0.0.1:8888.*0.0.0.0"') do set PID=%%i
taskkill /PID %PID% /F
echo Nice to meet you!
pause>nul