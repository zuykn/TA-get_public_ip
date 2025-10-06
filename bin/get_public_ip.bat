@echo off

REM Script: get_public_ip.bat
REM Author: zuykn.io
REM Copyright 2023-2025 zuykn
REM
REM Licensed under the Apache License, Version 2.0 (the "License");
REM you may not use this file except in compliance with the License.
REM You may obtain a copy of the License at
REM
REM     http://www.apache.org/licenses/LICENSE-2.0
REM
REM Unless required by applicable law or agreed to in writing, software
REM distributed under the License is distributed on an "AS IS" BASIS,
REM WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
REM See the License for the specific language governing permissions and
REM limitations under the License.

SETLOCAL ENABLEEXTENSIONS ENABLEDELAYEDEXPANSION

REM Defaults
set "TIMEOUT=10"
set "HTTPS_URL=https://checkip.amazonaws.com"
set "DNS_PROVIDER=opendns"
set "MODE=auto"
set "FORCED_COMMAND="
set "DNS_SPECIFIED=0"
set "HTTPS_ONLY_SPECIFIED=0"
set "DNS_ONLY_SPECIFIED=0"

:parse_loop
if "%~1"=="" goto parse_done
set "ARG=%~1"
if /I "%ARG%"=="-h"  goto usage_ok
if /I "%ARG%"=="-help" goto usage_ok
if /I "%ARG%"=="--help" goto usage_ok
if /I "%ARG%"=="-timeout" (
    if "%~2"=="" goto usage_err
    set "TIMEOUT=%~2"
    shift
    shift
    goto parse_loop
)
if /I "%ARG%"=="-https" (
    if "%~2"=="" goto usage_err
    echo.%~2| findstr /I /C:"https://" >nul
    if errorlevel 1 (
        set "HTTPS_URL=https://%~2"
    ) else (
        set "HTTPS_URL=%~2"
    )
    shift
    shift
    goto parse_loop
)
if /I "%ARG%"=="-dns" (
    if "%~2"=="" goto usage_err
    if /I "%~2"=="opendns" (
        set "DNS_PROVIDER=opendns"
        set "DNS_SPECIFIED=1"
    ) else if /I "%~2"=="google" (
        set "DNS_PROVIDER=google"
        set "DNS_SPECIFIED=1"
    ) else if /I "%~2"=="cloudflare" (
        set "DNS_PROVIDER=cloudflare"
        set "DNS_SPECIFIED=1"
    ) else (
        echo ERROR: Invalid DNS provider "%~2". Must be: opendns, google, or cloudflare 1>&2
        goto usage_err
    )
    shift
    shift
    goto parse_loop
)
if /I "%ARG%"=="-https-only" (
    set "MODE=https-only"
    set "HTTPS_ONLY_SPECIFIED=1"
    shift
    goto parse_loop
)
if /I "%ARG%"=="-dns-only" (
    set "MODE=dns-only"
    set "DNS_ONLY_SPECIFIED=1"
    shift
    goto parse_loop
)
if /I "%ARG%"=="-command" (
    if "%~2"=="" goto usage_err
    for %%C in (curl certutil bitsadmin nslookup) do if /I "%%C"=="%~2" set "FORCED_COMMAND=%%C" & goto after_cmd
    goto usage_err
:after_cmd
    shift
    shift
    goto parse_loop
)
echo ERROR: Unknown flag %ARG% 1>&2
goto usage_err

:parse_done

if "%HTTPS_ONLY_SPECIFIED%"=="1" (
    if "%DNS_ONLY_SPECIFIED%"=="1" (
        echo ERROR: Cannot specify both -https-only and -dns-only 1>&2
        call :print_usage
        exit /b 1
    )
)

set "BASE_HOST=%HTTPS_URL:https://=%"
for /f "delims=/ tokens=1" %%A in ("%BASE_HOST%") do set "BASE_HOST=%%A"

if defined FORCED_COMMAND (
    call :forced_fetch
    goto :eof
)

if /I "%MODE%"=="https-only" goto run_https_only
if /I "%MODE%"=="dns-only" goto run_dns_only
goto run_auto

:run_https_only
call :fetch_https
if errorlevel 1 exit /b 1
goto :eof

:run_dns_only
call :fetch_dns
if errorlevel 1 exit /b 1
goto :eof

:run_auto
if "%DNS_SPECIFIED%"=="1" (
    call :fetch_dns
    if not errorlevel 1 goto :eof
    call :fetch_https
    if errorlevel 1 exit /b 1
) else (
    call :fetch_https
    if not errorlevel 1 goto :eof
    call :fetch_dns
    if errorlevel 1 exit /b 1
)
goto :eof

:usage_ok
call :print_usage
exit /b 0

:usage_err
call :print_usage
exit /b 1

:print_usage
echo Usage: .\get_public_ip.bat [-timeout ^<seconds^>] [-https ^<host[/path]^>] [-dns ^<provider^>] [-https-only] [-dns-only] [-command ^<command^>]
echo.
echo Providers (for -dns):
echo   opendns ^| google ^| cloudflare
echo Commands (for -command):
echo   curl ^| certutil ^| bitsadmin ^| nslookup
echo Modes:
echo   -https-only   Use HTTPS methods only (no DNS fallback)
echo   -dns-only     Use DNS method only (skip HTTPS)
echo Notes:
echo   Supplying both -https-only and -dns-only is an error.
echo   -command forces use of exactly one retrieval tool and bypasses fallback logic.
echo   If -command is set it must not conflict with a chosen mode (e.g. forcing nslookup with -https-only).
echo Examples:
echo   .\get_public_ip.bat -timeout 5
echo   .\get_public_ip.bat -https ipinfo.io/ip
echo   .\get_public_ip.bat -dns cloudflare
echo   .\get_public_ip.bat -dns-only -dns google
echo   .\get_public_ip.bat -https-only -https checkip.amazonaws.com
echo   .\get_public_ip.bat -command certutil
goto :eof


:forced_fetch
if /I "%MODE%"=="https-only" (
    if /I "%FORCED_COMMAND%"=="nslookup" (
        echo ERROR: Cannot use nslookup command with https-only mode 1>&2
        goto usage_err
    )
)
if /I "%MODE%"=="dns-only" (
    if /I "%FORCED_COMMAND%"=="curl" (
        echo ERROR: Cannot use curl command with dns-only mode 1>&2
        goto usage_err
    )
    if /I "%FORCED_COMMAND%"=="certutil" (
        echo ERROR: Cannot use certutil command with dns-only mode 1>&2
        goto usage_err
    )
    if /I "%FORCED_COMMAND%"=="bitsadmin" (
        echo ERROR: Cannot use bitsadmin command with dns-only mode 1>&2
        goto usage_err
    )
)
if /I "%FORCED_COMMAND%"=="curl" (
    call :https_curl && exit /b 0
    exit /b 1
)
if /I "%FORCED_COMMAND%"=="certutil" (
    call :https_certutil && exit /b 0
    exit /b 1
)
if /I "%FORCED_COMMAND%"=="bitsadmin" (
    call :https_bitsadmin && exit /b 0
    exit /b 1
)
if /I "%FORCED_COMMAND%"=="nslookup" (
    call :dns_nslookup && exit /b 0
    exit /b 1
)
exit /b 1


:fetch_https
call :https_curl && exit /b 0
call :https_certutil && exit /b 0
call :https_bitsadmin && exit /b 0
exit /b 1

:https_curl
where curl >nul 2>&1 || exit /b 1
for /f %%A in ('curl -ks --max-time %TIMEOUT% "%HTTPS_URL%" 2^>nul') do (
    call :validate_and_output "%%A,4,https,%BASE_HOST%,curl"
    if not errorlevel 1 exit /b 0
)

if not "%HTTPS_URL%"=="https://checkip.amazonaws.com" (
    for /f %%A in ('curl -ks --max-time %TIMEOUT% "https://checkip.amazonaws.com" 2^>nul') do (
        call :validate_and_output "%%A,4,https,checkip.amazonaws.com,curl"
        if not errorlevel 1 exit /b 0
    )
)
exit /b 1

:https_certutil
where certutil >nul 2>&1 || exit /b 1
set "tmpfile=%~dp0getip_%RANDOM%.tmp"
certutil -urlcache -split -f "%HTTPS_URL%" "!tmpfile!" >nul 2>&1
if exist "!tmpfile!" (
    for /f %%A in ('type "!tmpfile!" 2^>nul') do (
        call :validate_and_output "%%A,4,https,%BASE_HOST%,certutil"
        if not errorlevel 1 (
            del "!tmpfile!" >nul 2>&1
            exit /b 0
        )
    )
    del "!tmpfile!" >nul 2>&1
)

if not "%HTTPS_URL%"=="https://checkip.amazonaws.com" (
    set "tmpfile=%~dp0getip_%RANDOM%.tmp"
    certutil -urlcache -split -f "https://checkip.amazonaws.com" "!tmpfile!" >nul 2>&1
    if exist "!tmpfile!" (
        for /f %%A in ('type "!tmpfile!" 2^>nul') do (
            call :validate_and_output "%%A,4,https,checkip.amazonaws.com,certutil"
            if not errorlevel 1 (
                del "!tmpfile!" >nul 2>&1
                exit /b 0
            )
        )
        del "!tmpfile!" >nul 2>&1
    )
)
exit /b 1

:https_bitsadmin
where bitsadmin >nul 2>&1 || exit /b 1
set "tmpfile=%~dp0getip_%RANDOM%.tmp"
bitsadmin /transfer getip "%HTTPS_URL%" "!tmpfile!" >nul 2>&1
if exist "!tmpfile!" (
    for /f %%A in ('type "!tmpfile!" 2^>nul') do (
        call :validate_and_output "%%A,4,https,%BASE_HOST%,bitsadmin"
        if not errorlevel 1 (
            del "!tmpfile!" >nul 2>&1
            exit /b 0
        )
    )
    del "!tmpfile!" >nul 2>&1
)

if not "%HTTPS_URL%"=="https://checkip.amazonaws.com" (
    set "tmpfile=%~dp0getip_%RANDOM%.tmp"
    bitsadmin /transfer getip_fallback "https://checkip.amazonaws.com" "!tmpfile!" >nul 2>&1
    if exist "!tmpfile!" (
        for /f %%A in ('type "!tmpfile!" 2^>nul') do (
            call :validate_and_output "%%A,4,https,checkip.amazonaws.com,bitsadmin"
            if not errorlevel 1 (
                del "!tmpfile!" >nul 2>&1
                exit /b 0
            )
        )
        del "!tmpfile!" >nul 2>&1
    )
)
exit /b 1


:fetch_dns
call :dns_nslookup && exit /b 0
exit /b 1

:dns_nslookup
where nslookup >nul 2>&1 || exit /b 1

if /I "%DNS_PROVIDER%"=="opendns" (
    call :dns_opendns && exit /b 0
) else if /I "%DNS_PROVIDER%"=="google" (
    call :dns_google && exit /b 0
    call :dns_opendns && exit /b 0
) else if /I "%DNS_PROVIDER%"=="cloudflare" (
    call :dns_cloudflare && exit /b 0
    call :dns_opendns && exit /b 0
)
exit /b 1

:dns_opendns
for /f "tokens=2 delims=: " %%A in ('nslookup myip.opendns.com resolver1.opendns.com 2^>nul ^| findstr /r /c:"Address:[ ]*[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*"') do set "ip=%%A"
if defined ip (
    set "ip=!ip: =!"
    call :validate_and_output "!ip!,4,dns,opendns,nslookup"
    if not errorlevel 1 exit /b 0
)
exit /b 1

:dns_google
setlocal
set "tmp=%~dp0google_dns.tmp"
nslookup -type=txt o-o.myaddr.l.google.com ns1.google.com 2>nul | findstr /r /c:"\"[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\"" > "%tmp%"
for /f "usebackq delims=" %%A in ("%tmp%") do (set "line=%%A" & goto :google_process)
:google_process
for /f "tokens=* delims= " %%B in ('echo(!line!') do set "line=%%B"
set "line=!line:"=!"
call :validate_and_output "!line!,4,dns,google,nslookup"
if not errorlevel 1 (
    del "%tmp%" >nul 2>&1
    endlocal
    exit /b 0
)
if not defined line (
    del "%tmp%" >nul 2>&1
    endlocal
    exit /b 1
)
del "%tmp%" >nul 2>&1
endlocal
exit /b 1

:dns_cloudflare
setlocal
set "tmp=%~dp0cloudflare_dns.tmp"
nslookup -class=CHAOS -q=TXT whoami.cloudflare 1.1.1.1 2>nul | findstr /r /c:"\"[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\"" > "%tmp%"
for /f "usebackq delims=" %%A in ("%tmp%") do (set "line=%%A" & goto :cloudflare_process)
:cloudflare_process
for /f "tokens=* delims= " %%B in ('echo(!line!') do set "line=%%B"
set "line=!line:"=!"
call :validate_and_output "!line!,4,dns,cloudflare,nslookup"
if not errorlevel 1 (
    del "%tmp%" >nul 2>&1
    endlocal
    exit /b 0
)
if not defined line (
    del "%tmp%" >nul 2>&1
    endlocal
    exit /b 1
)
del "%tmp%" >nul 2>&1
endlocal
exit /b 1


:validate_and_output
setlocal
set "result=%~1"

for /f "tokens=1 delims=," %%A in ("%result%") do set "ip_part=%%A"

set "ip_part=!ip_part:"=!"

echo !ip_part! | findstr /r "[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*" >nul
if errorlevel 1 (
    endlocal
    exit /b 1
)

for /f "tokens=1,2,3,4 delims=." %%A in ("!ip_part!") do (
    if %%A gtr 255 (endlocal & exit /b 1)
    if %%B gtr 255 (endlocal & exit /b 1)
    if %%C gtr 255 (endlocal & exit /b 1)
    if %%D gtr 255 (endlocal & exit /b 1)
)

for /f "tokens=1* delims=," %%A in ("%result%") do set "metadata=%%B"

<nul set /p "=!ip_part!,!metadata!"
endlocal
exit /b 0
