@echo OFF

SETLOCAL EnableExtensions

FOR /F "tokens=2,*" %%i IN ('reg query "HKLM\SOFTWARE\Valve\Steam" /v "InstallPath" ^| Find /i "InstallPath"')   DO set SteamDirectory=%%j

@echo Steam directory is: %SteamDirectory%

set InstallPath=%SteamDirectory%\steamapps\common\Natural Selection 2

@echo NS2 install path is: %InstallPath%
@echo Mod directory is: %~dp0

start /d"%InstallPath%" .\ns2.exe -game "%~dp0"