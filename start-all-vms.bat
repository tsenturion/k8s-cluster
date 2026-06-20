@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

set "VBOXMANAGE=%ProgramFiles%\Oracle\VirtualBox\VBoxManage.exe"
if not exist "%VBOXMANAGE%" set "VBOXMANAGE=VBoxManage"

echo Последовательный запуск Kubernetes VM...
echo Порядок: master1, master2, master3, worker1, worker2
echo.

call :start_vm master1
call :start_vm master2
call :start_vm master3
call :start_vm worker1
call :start_vm worker2

echo.
echo Обработка запуска завершена.
exit /b 0

:start_vm
set "VM=%~1"

"%VBOXMANAGE%" showvminfo "%VM%" --machinereadable 2>nul | findstr /b /c:"VMState=" | findstr /c:"running" >nul
if not errorlevel 1 (
    echo %VM% уже запущена, пропускаю.
    exit /b 0
)

echo Запуск %VM%...
"%VBOXMANAGE%" startvm "%VM%" --type headless

if errorlevel 1 (
    echo Не удалось запустить %VM%.
    exit /b 1
)

echo %VM% запущена.
exit /b 0
