@echo off

call :vsCheck
if %ERRORLEVEL%==0 call :vsBuild %*
exit /b %ERRORLEVEL%

:: Requirements:
:: - MSVC (Visual Studio)
:: - CMake
:vsCheck
if not exist "%ProgramFiles(x86)%\Microsoft Visual Studio" exit /b 1
where cmake > nul
exit /b %ERRORLEVEL%

:vsBuild
set USER_ARGS=%*
set MSVC_YYYY=
set MSVC_EDITION=
set GENERATOR=
set CONFIGURE=0

:: Get Latest MSVC
:: "for /f" will always replace the result, so the final result is the last line (latest version)
for /f "tokens=* USEBACKQ" %%A in (`dir /a:d /b "%ProgramFiles(x86)%\Microsoft Visual Studio\" ^| findstr "^[0-9]"`) do set MSVC_YYYY=%%A

:: Get MSVC Edition
:: Make sure only the following are allowed, prefer the lesser license
if exist "%ProgramFiles(x86)%\Microsoft Visual Studio\%MSVC_YYYY%\BuildTools" (
    set MSVC_EDITION=BuildTools
) else if exist "%ProgramFiles(x86)%\Microsoft Visual Studio\%MSVC_YYYY%\Community" (
    set MSVC_EDITION=Community
) else if exist "%ProgramFiles(x86)%\Microsoft Visual Studio\%MSVC_YYYY%\Professional" (
    set MSVC_EDITION=Professional
) else if exist "%ProgramFiles(x86)%\Microsoft Visual Studio\%MSVC_YYYY%\Enterprise" (
    set MSVC_EDITION=Enterprise
)

:: Setup compiler environment, this needs to be called before CMake
if "%VSCMD_VER%"=="" call "%ProgramFiles(x86)%\Microsoft Visual Studio\%MSVC_YYYY%\%MSVC_EDITION%\VC\Auxiliary\Build\vcvarsall.bat" %PROCESSOR_ARCHITECTURE%

:: Optionally use Ninja if found, else leave it to use the latest MSVC set by vcvarsall.bat
where ninja > nul
if %ERRORLEVEL%==0 set GENERATOR=-G Ninja

:: Remove Ninja if user specified a generator
echo %USER_ARGS% | findstr c:"-G" > nul
if %ERRORLEVEL%==0 set GENERATOR=

:: Configure CMake
:: If it was previously configured by vscode CMake, then reconfigure as well
findstr CMAKE_BUILD_TYPE: build\CMakeCache.txt | findstr Debug > nul
if %ERRORLEVEL%==0 set CONFIGURE=1
type nul > nul
if not exist build\build.ninja set CONFIGURE=1
if not exist build\CMakeCache.txt set CONFIGURE=1
if %CONFIGURE%==1 rmdir build /s /q
if not exist build cmake -S . -B build %GENERATOR% %USER_ARGS% -DCMAKE_BUILD_TYPE=Release
if %ERRORLEVEL% neq 0 exit /b %ERRORLEVEL%

:: Build
cmake --build build --config "Release" --target package

exit /b %ERRORLEVEL%