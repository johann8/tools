@echo off

title RustDesk
mode con:cols=50 lines=5
%1 mshta vbscript:CreateObject("Shell.Application").ShellExecute("cmd.exe","/c %~s0 ::","","runas",1)(window.close)&&exit >nul 2>&1

title RustDesk
mode con:cols=95 lines=20

:: If you have a Rustdesk server, type the domain name or ip address. Example: set domain=-host=192.168.1.1
:: changeme
set domain=-host=xxx.xxx.xxx.xxx

:: If you have a Rustdesk server, type the key your server generated. Example: set key=ghtYUjykk2489=
:: changeme
set key=xxxxxxxxxxxxxxxxxxxx=

:: **** Please set here the version of the agent you use. 
:: **** Change it to upgrade the agent on all computer.
set VERSION=121
set VERSION_URL=1.2.1

IF %PROCESSOR_ARCHITECTURE%==x86 SET INSTALLDIR=%ProgramFiles(x86)%
IF %PROCESSOR_ARCHITECTURE%==AMD64 SET INSTALLDIR=%ProgramFiles%

:: NOTE: 
:: If you do not specify domain and key, RustDesk software will be installed with default settings.


cd /d %temp%
echo.
echo.
echo    RustDesk
echo.
echo.

IF EXIST "%INSTALLDIR%\RustDesk\rustdesk.exe" goto upgrade

:install 
:: Rustdesk software will be downloaded and installed as an release only.
:: You may need to manually change the github link in the script when Rustdesk releases the stable version of the software.
echo    RustDesk downloading software, please wait...
start /wait /min powershell -Command "(New-Object Net.WebClient).DownloadFile('https://github.com/rustdesk/rustdesk/releases/download/%VERSION_URL%/rustdesk-%VERSION_URL%-x86_64.exe', 'rustdesk%domain%,key=%key%.exe')" >nul 2>&1

echo.
echo    Installing RustDesk software, please wait...
start /wait rustdesk%domain%,key=%key%.exe --silent-install
echo.
echo.
echo   !!! INSTALLATION COMPLETED !!!
echo.
echo.
echo    You can run the program via the shortcut created on the desktop or the Start Menu...
del /f /q "rustdesk%domain%,key=%key%.exe" >nul
cd "%INSTALLDIR%\RustDesk\"
echo rustdesk > %VERSION%.txt
echo.
echo.
choice /N /C 123 /T 5 /D 1 /M "Wait 5 sec... "
echo.
echo.
goto end

:upgrade
:: Rustdesk software will be downloaded and upgraded as an release only.

IF EXIST "%INSTALLDIR%\RustDesk\%VERSION%.txt" goto message
echo    RustDesk downloading software, please wait...
start /wait /min powershell -Command "(New-Object Net.WebClient).DownloadFile('https://github.com/rustdesk/rustdesk/releases/download/1.2.1/rustdesk-1.2.1-x86_64.exe', 'rustdesk%domain%,key=%key%.exe')" >nul 2>&1

echo.
echo    Upgrading RustDesk software, please wait...
start /wait rustdesk%domain%,key=%key%.exe --silent-install
echo.
echo.
echo   !!! UPGRADE COMPLETED !!!
echo.
echo.
echo    You can run the program via the shortcut created on the desktop or the Start Menu...
del /f /q "rustdesk%domain%,key=%key%.exe" >nul
cd "%INSTALLDIR%\RustDesk\"
echo rustdesk > %VERSION%.txt
echo.
echo.
choice /N /C 123 /T 5 /D 1 /M "Wait 5 sec... "
echo.
echo.
goto end

:message
echo You have already installed the latest version of Rustdesk
echo.
echo.
choice /N /C 123 /T 5 /D 1 /M "Wait 5 sec... "
goto end

:end
exit

