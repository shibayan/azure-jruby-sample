@if "%SCM_TRACE_LEVEL%" NEQ "4" @echo off

:: ----------------------
:: KUDU Deployment Script
:: Version: 0.2.2
:: ----------------------

:: Prerequisites
:: -------------

:: Verify node.js installed
where node 2>nul >nul
IF %ERRORLEVEL% NEQ 0 (
  echo Missing node.js executable, please install node.js, if already installed make sure it can be reached from current environment.
  goto error
)

:: Setup
:: -----

setlocal enabledelayedexpansion

SET ARTIFACTS=%~dp0%..\artifacts

IF NOT DEFINED DEPLOYMENT_SOURCE (
  SET DEPLOYMENT_SOURCE=%~dp0%.
)

IF NOT DEFINED DEPLOYMENT_TARGET (
  SET DEPLOYMENT_TARGET=%ARTIFACTS%\wwwroot
)

IF NOT DEFINED NEXT_MANIFEST_PATH (
  SET NEXT_MANIFEST_PATH=%ARTIFACTS%\manifest

  IF NOT DEFINED PREVIOUS_MANIFEST_PATH (
    SET PREVIOUS_MANIFEST_PATH=%ARTIFACTS%\manifest
  )
)

IF NOT DEFINED KUDU_SYNC_CMD (
  :: Install kudu sync
  echo Installing Kudu Sync
  call npm install kudusync -g --silent
  IF !ERRORLEVEL! NEQ 0 goto error

  :: Locally just running "kuduSync" would also work
  SET KUDU_SYNC_CMD=%appdata%\npm\kuduSync.cmd
)

::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: Runtime Install
:: ----------
set JRUBY_VERSION=1.7.20
set JRUBY_HOME=%DEPLOYMENT_TARGET%\bin\jruby-%JRUBY_VERSION%
set JRUBY_EXE=%JRUBY_HOME%\bin\jruby.exe
set JRUBY_GEM_CMD=%JRUBY_HOME%\bin\gem
set JRUBY_BUNDLER_CMD=%JRUBY_HOME%\bin\bundle

set JAVA_OPTS=-Djava.net.preferIPv4Stack=true

IF NOT EXIST %JRUBY_HOME% (
  echo Installing JRuby %JRUBY_VERSION%

  PUSHD "%DEPLOYMENT_TARGET%"

  mkdir bin & cd bin

  curl -LOs https://s3.amazonaws.com/jruby.org/downloads/%JRUBY_VERSION%/jruby-bin-%JRUBY_VERSION%.zip
  unzip -q jruby-bin-%JRUBY_VERSION%.zip & rm -f jruby-bin-%JRUBY_VERSION%.zip

  POPD
)

IF NOT EXIST %JRUBY_BUNDLER_CMD% (
  echo Installing bundler

  %JRUBY_EXE% -S "%JRUBY_GEM_CMD%" install bundler --no-ri --no-rdoc --quiet > nul
  IF !ERRORLEVEL! NEQ 0 goto error
)

::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: Deployment
:: ----------

echo Handling Basic Web Site deployment.

:: 1. KuduSync
IF /I "%IN_PLACE_DEPLOYMENT%" NEQ "1" (
  call :ExecuteCmd "%KUDU_SYNC_CMD%" -v 50 -f "%DEPLOYMENT_SOURCE%" -t "%DEPLOYMENT_TARGET%" -n "%NEXT_MANIFEST_PATH%" -p "%PREVIOUS_MANIFEST_PATH%" -i ".git;.hg;.deployment;deploy.cmd;bin"
  IF !ERRORLEVEL! NEQ 0 goto error
)

:: 2. Exec Bundler
IF EXIST "%DEPLOYMENT_TARGET%\Gemfile" (
  echo Executing bundle install

  PUSHD "%DEPLOYMENT_TARGET%"
  
  %JRUBY_EXE% -S "%JRUBY_BUNDLER_CMD%" install --without development:test --path vendor/bundle --binstubs vendor/bundle/bin -j4
  IF !ERRORLEVEL! NEQ 0 goto error
  
  POPD
)

::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

:: Post deployment stub
IF DEFINED POST_DEPLOYMENT_ACTION call "%POST_DEPLOYMENT_ACTION%"
IF !ERRORLEVEL! NEQ 0 goto error

goto end

:: Execute command routine that will echo out when error
:ExecuteCmd
setlocal
set _CMD_=%*
call %_CMD_%
if "%ERRORLEVEL%" NEQ "0" echo Failed exitCode=%ERRORLEVEL%, command=%_CMD_%
exit /b %ERRORLEVEL%

:error
endlocal
echo An error has occurred during web site deployment.
call :exitSetErrorLevel
call :exitFromFunction 2>nul

:exitSetErrorLevel
exit /b 1

:exitFromFunction
()

:end
endlocal
echo Finished successfully.
