@echo off

if "%1"=="" goto use_default
set NAME=%1
goto have_name

:use_default
set NAME=NY

:have_name
echo [*] Building New Year Timer...

REM Create bin directory
if not exist bin md bin

REM Goto src directory
cd src

REM Compile %NAME%.asm to %NAME%.obj
..\masm\masm %NAME%.asm;
if errorlevel 1 goto build_failed

REM Link %NAME%.obj to %NAME%.exe
..\masm\link %NAME%.obj;
if errorlevel 1 goto build_failed

REM Copy %NAME%.exe to bin
copy %NAME%.exe ..\bin\%NAME%.exe >nul
if errorlevel 1 goto copy_failed

REM Del %NAME%.exe and %NAME%.obj from src
del %NAME%.exe
del %NAME%.obj


echo [OK] Build successful: bin\%NAME%.exe

cd ..
goto end

:copy_failed
echo [ERROR] Build succeeded, but failed to copy src\%NAME%.exe to bin\
echo Check that bin\ exists and try again.
cd ..
goto end

:build_failed
echo [ERROR] Build failed! Check MASM / LINK messages above.

cd ..

:end