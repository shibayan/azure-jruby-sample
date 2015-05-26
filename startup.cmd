@echo off

SET WWWROOT_DIR=%~dp0
SET PROCFILE=%WWWROOT_DIR%Procfile

IF DEFINED PATH_EXTEND (
  SET "PATH=%PATH_EXTEND%;%PATH%"
)

cd /d %WWWROOT_DIR%

IF NOT EXIST %PROCFILE% (
  exit 1
)

FOR /f "delims=: tokens=1,2" %%i IN (%PROCFILE%) DO (
  IF "%%i" == "web" (
    SET EXECUTE_CMD=%%j
  )
)

CALL %EXECUTE_CMD%