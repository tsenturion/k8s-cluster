@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "VBOXMANAGE=%ProgramFiles%\Oracle\VirtualBox\VBoxManage.exe"
if not exist "%VBOXMANAGE%" set "VBOXMANAGE=%ProgramFiles(x86)%\Oracle\VirtualBox\VBoxManage.exe"
if not exist "%VBOXMANAGE%" (
    where VBoxManage.exe >nul 2>&1
    if errorlevel 1 (
        echo ERROR: VBoxManage.exe not found. Check VirtualBox installation or PATH.
        pause
        exit /b 1
    )
    set "VBOXMANAGE=VBoxManage.exe"
)

echo Starting Kubernetes VMs sequentially...
echo Order: master1, master2, master3, worker1, worker2
echo.

call :start_vm master1
call :start_vm master2
call :start_vm master3
call :start_vm worker1
call :start_vm worker2

echo.
echo Start sequence completed. Running VMs:
"%VBOXMANAGE%" list runningvms
exit /b 0

:start_vm
set "VM=%~1"

call :is_running "%VM%"
if not errorlevel 1 (
    echo %VM% is already running, skipping.
    exit /b 0
)

echo Starting %VM%...
"%VBOXMANAGE%" startvm "%VM%" --type headless
if errorlevel 1 (
    echo ERROR: Failed to start %VM%.
    pause
    exit /b 1
)

call :is_running "%VM%"
if errorlevel 1 (
    echo ERROR: %VM% did not reach running state.
    pause
    exit /b 1
)

echo %VM% started.
exit /b 0

:is_running
set "CHECK_VM=%~1"
"%VBOXMANAGE%" list runningvms | findstr /i /c:"%CHECK_VM%" >nul
exit /b %errorlevel%
