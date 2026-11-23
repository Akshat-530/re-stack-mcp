@echo off
REM  RE-Stack - Windows-side BRIDGE controller (ALL tools)
REM    x64dbg / x32dbg  ->  127.0.0.1:27042
REM    frida-server     ->  127.0.0.1:27043
REM    host agent       ->  127.0.0.1:27044
REM  Usage: Bridge.bat [start ^| start x32 ^| stop ^| status]
setlocal EnableExtensions
set "TOOLS=%~dp0"
set "X64=C:\x64dbg\release\x64\x64dbg.exe"
set "X32=C:\x64dbg\release\x32\x32dbg.exe"
set "FS=%TOOLS%frida-server.exe"
set "AGENT=%TOOLS%host_agent.ps1"
set "FRIDA_VER=17.25.1"
set "AGENT_PORT=27044"

set "CMD=%~1"
if /I "%CMD%"=="" set "CMD=start"
if /I "%CMD%"=="stop"   goto stop
if /I "%CMD%"=="status" goto status
if /I "%CMD%"=="start"  goto start
echo Usage: Bridge.bat [start^|start x32^|stop^|status]
exit /b 1

:start
tasklist /FI "IMAGENAME eq x64dbg.exe" 2>NUL | find /I "x64dbg.exe" >NUL
if errorlevel 1 ( start "" "%X64%" & echo [x64dbg] launching - plugin up on 27042 in ~10s ) else ( echo [x64dbg] already running )
if /I "%~2"=="x32" (
  tasklist /FI "IMAGENAME eq x32dbg.exe" 2>NUL | find /I "x32dbg.exe" >NUL
  if errorlevel 1 ( start "" "%X32%" & echo [x32dbg] launching ) else ( echo [x32dbg] already running )
)
tasklist /FI "IMAGENAME eq powershell.exe" 2>NUL | find /I "powershell.exe" >NUL
if errorlevel 1 (
  start "" /min powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%AGENT%" -Port %AGENT_PORT%
  echo [agent] host agent launching on 127.0.0.1:%AGENT_PORT%
) else (
  echo [agent] powershell.exe already running - assuming agent is up
)
if not exist "%FS%" (
  echo [frida] downloading frida-server %FRIDA_VER% ...
  curl.exe -L -s -o "%TOOLS%fs.xz" "https://github.com/frida/frida/releases/download/%FRIDA_VER%/frida-server-%FRIDA_VER%-windows-x86_64.exe.xz"
  if exist "%TOOLS%fs.xz" (
    tar -xf "%TOOLS%fs.xz" -C "%TOOLS%"
    del "%TOOLS%fs.xz" >NUL 2>&1
    if exist "%TOOLS%frida-server-%FRIDA_VER%-windows-x86_64.exe" ren "%TOOLS%frida-server-%FRIDA_VER%-windows-x86_64.exe" frida-server.exe
  )
)
if exist "%FS%" (
  tasklist /FI "IMAGENAME eq frida-server.exe" 2>NUL | find /I "frida-server.exe" >NUL
  if errorlevel 1 ( start "" /min "%FS%" -l 127.0.0.1:27043 & echo [frida] frida-server launching on 127.0.0.1:27043 ) else ( echo [frida] already running )
) else (
  echo [frida] frida-server unavailable (download failed) - skipping
)
ping -n 8 127.0.0.1 >nul
goto status

:stop
taskkill /IM x64dbg.exe /F >NUL 2>&1
taskkill /IM x32dbg.exe /F >NUL 2>&1
taskkill /IM frida-server.exe /F >NUL 2>&1
for /f "tokens=5" %%p in ('netstat -ano ^| findstr /C:":%AGENT_PORT%" ^| findstr LISTENING') do taskkill /PID %%p /F >NUL 2>&1
echo [stop] x64dbg/x32dbg/frida-server/host-agent terminated
exit /b 0

:status
for %%P in (27042 27043 %AGENT_PORT%) do (
  netstat -ano | findstr /C:":%%P" | findstr /I "LISTENING" >NUL
  if errorlevel 1 ( echo [port] %%P NOT listening ) else ( echo [port] %%P LISTENING )
)
for /f "usebackq delims=" %%i in (`curl.exe -s -o NUL -w "%%{http_code}" http://127.0.0.1:%AGENT_PORT%/health 2^>NUL`) do (
  if "%%i"=="000" (echo [agent] /health UNREACHABLE) else (echo [agent] /health ALIVE - HTTP %%i)
)
exit /b 0
