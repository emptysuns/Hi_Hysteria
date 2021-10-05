@echo off
echo Hello World!
REG add "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyEnable /t REG_DWORD /d 1 /f 
REG ADD "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings" /v AutoDetect /t REG_DWORD /f /D 0
REG add "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyServer /d "127.0.0.1:8888" /f
REG add "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyOverride /t REG_SZ /d "localhost;127.*;10.*;172.16.*;172.17.*;172.18.*;172.19.*;172.20.*;172.21.*;172.22.*;172.23.*;172.24.*;172.25.*;172.26.*;172.27.*;172.28.*;172.29.*;172.30.*;172.31.*;192.168.*" /f
start "Hysteria" /b cmd /c script\front_client.bat
echo Succees!Input 'Enter' to stop me.
:running
pause>nul
set check="Y"
set /p check=Confirm to Stop!? Y(default) or n:
if /i "%check%"=="Y" goto stop
if /i "%check%"=="n" goto running else(goto stop)
:stop
echo Start Clear! 
REG add "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyEnable /t REG_DWORD /d 0 /f
REG add "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyServer /d "" /f
REG add "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyOverride /t REG_SZ /d "" /f
REG ADD "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings" /v AutoDetect /t REG_DWORD /f /D 1
for /f "tokens=5 delims= " %%i in ('netstat -ano ^| findstr "127.0.0.1:8888.*0.0.0.0"') do set PID=%%i
taskkill /PID %PID% /F
echo Nice to meet you!
pause>nul