@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

set "VBOXMANAGE=%ProgramFiles%\Oracle\VirtualBox\VBoxManage.exe"
if not exist "%VBOXMANAGE%" set "VBOXMANAGE=VBoxManage"

echo Последовательное завершение Kubernetes VM...
echo Порядок: worker2, worker1, master3, master2, master1
echo.

call :shutdown_vm worker2
call :shutdown_vm worker1
call :shutdown_vm master3
call :shutdown_vm master2
call :shutdown_vm master1

echo.
echo Все Kubernetes VM остановлены.
exit /b 0

:shutdown_vm
set "VM=%~1"

"%VBOXMANAGE%" showvminfo "%VM%" --machinereadable 2>nul | findstr /b /c:"VMState=" | findstr /c:"running" >nul
if errorlevel 1 (
    echo %VM% уже остановлена или не запущена.
    exit /b 0
)

echo Завершение %VM%...
"%VBOXMANAGE%" controlvm "%VM%" acpipowerbutton

:wait_vm
timeout /t 5 >nul
"%VBOXMANAGE%" showvminfo "%VM%" --machinereadable 2>nul | findstr /b /c:"VMState=" | findstr /c:"running" >nul
if not errorlevel 1 (
    echo Ожидание остановки %VM%...
    goto wait_vm
)

echo %VM% остановлена.
exit /b 0
