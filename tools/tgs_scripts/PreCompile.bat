@echo off
rem TGS runs this before every Windows deploy. %1 is the folder the game is being deployed to.
rem Fails the deploy if the Rust libraries are older than the Rust code, so the server keeps running its last good build.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~1\tools\ci\rustlibs_source_hash.ps1" -Root "%~1" -Check
exit /b %ERRORLEVEL%
