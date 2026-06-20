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

set "WAIT_SECONDS=5"
set "RETRY_EVERY_LOOPS=3"
set /a PING_WAIT_COUNT=WAIT_SECONDS + 1

echo Stopping Kubernetes VMs sequentially...
echo Order: worker2, worker1, master3, master2, master1
echo ACPI signal will be retried every 15 seconds until each VM stops.
echo.

call :shutdown_vm worker2
call :shutdown_vm worker1
call :shutdown_vm master3
call :shutdown_vm master2
call :shutdown_vm master1

echo.
echo Stop sequence completed. Remaining running VMs:
"%VBOXMANAGE%" list runningvms
exit /b 0

:shutdown_vm
set "VM=%~1"

call :is_running "%VM%"
if errorlevel 1 (
    echo %VM% is already stopped or not running.
    exit /b 0
)

echo.
echo Stopping %VM%...
"%VBOXMANAGE%" controlvm "%VM%" acpipowerbutton
if errorlevel 1 (
    echo ERROR: Failed to send ACPI signal to %VM%.
    pause
    exit /b 1
)

set /a WAIT_LOOP=0

:wait_vm
ping -n %PING_WAIT_COUNT% 127.0.0.1 >nul
call :is_running "%VM%"
if errorlevel 1 (
    echo %VM% stopped.
    exit /b 0
)

set /a WAIT_LOOP+=1
echo Waiting for %VM% to stop... attempt !WAIT_LOOP!

set /a RETRY_MOD=WAIT_LOOP %% RETRY_EVERY_LOOPS
if !RETRY_MOD!==0 (
    echo Retrying ACPI signal for %VM%...
    "%VBOXMANAGE%" controlvm "%VM%" acpipowerbutton
    if errorlevel 1 (
        echo ERROR: Failed to retry ACPI signal for %VM%.
        pause
        exit /b 1
    )
)

goto wait_vm

:is_running
set "CHECK_VM=%~1"
"%VBOXMANAGE%" list runningvms | findstr /i /c:"%CHECK_VM%" >nul
exit /b %errorlevel%
