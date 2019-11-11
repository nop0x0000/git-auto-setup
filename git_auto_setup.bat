@echo off
echo %~dp0
pushd %~dp0
powershell -NoProfile -ExecutionPolicy Unrestricted .\git_auto_setup.ps1
popd
exit