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

set "DEFAULT_HTTPS_IPV4=https://ipv4.icanhazip.com"
set "DEFAULT_HTTPS_IPV6=https://ipv6.icanhazip.com"
set "DEFAULT_DNS_PROVIDER=opendns"

set "TIMEOUT=5"
set "HTTPS_URL=%DEFAULT_HTTPS_IPV4%"
set "HTTPS_URL_IPV4=%DEFAULT_HTTPS_IPV4%"
set "HTTPS_URL_IPV6=%DEFAULT_HTTPS_IPV6%"
set "DNS_PROVIDER=%DEFAULT_DNS_PROVIDER%"
set "DNS_PROVIDER_IPV4=%DEFAULT_DNS_PROVIDER%"
set "DNS_PROVIDER_IPV6=%DEFAULT_DNS_PROVIDER%"
set "MODE=auto"
set "FORCED_COMMAND="
set "IP_ONLY=0"
set "IP_VERSION_FILTER="
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
        set "HTTPS_URL_IPV4=https://%~2"
        set "HTTPS_URL_IPV6=https://%~2"
    ) else (
        set "HTTPS_URL=%~2"
        set "HTTPS_URL_IPV4=%~2"
        set "HTTPS_URL_IPV6=%~2"
    )
    shift
    shift
    goto parse_loop
)
if /I "%ARG%"=="-https-4" (
    if "%~2"=="" goto usage_err
    echo.%~2| findstr /I /C:"https://" >nul
    if errorlevel 1 (
        set "HTTPS_URL_IPV4=https://%~2"
    ) else (
        set "HTTPS_URL_IPV4=%~2"
    )
    shift
    shift
    goto parse_loop
)
if /I "%ARG%"=="-https-6" (
    if "%~2"=="" goto usage_err
    echo.%~2| findstr /I /C:"https://" >nul
    if errorlevel 1 (
        set "HTTPS_URL_IPV6=https://%~2"
    ) else (
        set "HTTPS_URL_IPV6=%~2"
    )
    shift
    shift
    goto parse_loop
)
if /I "%ARG%"=="-dns" (
    if "%~2"=="" goto usage_err
    if /I "%~2"=="opendns" (
        set "DNS_PROVIDER=opendns"
        set "DNS_PROVIDER_IPV4=opendns"
        set "DNS_PROVIDER_IPV6=opendns"
        set "DNS_SPECIFIED=1"
    ) else if /I "%~2"=="cloudflare" (
        set "DNS_PROVIDER=cloudflare"
        set "DNS_PROVIDER_IPV4=cloudflare"
        set "DNS_PROVIDER_IPV6=cloudflare"
        set "DNS_SPECIFIED=1"
    ) else (
        echo ERROR: Invalid DNS provider "%~2". Must be: opendns or cloudflare 1>&2
        goto usage_err
    )
    shift
    shift
    goto parse_loop
)
if /I "%ARG%"=="-dns-4" (
    if "%~2"=="" goto usage_err
    if /I "%~2"=="opendns" (
        set "DNS_PROVIDER_IPV4=opendns"
        set "DNS_SPECIFIED=1"
    ) else if /I "%~2"=="cloudflare" (
        set "DNS_PROVIDER_IPV4=cloudflare"
        set "DNS_SPECIFIED=1"
    ) else (
        echo ERROR: Invalid DNS provider "%~2". Must be: opendns or cloudflare 1>&2
        goto usage_err
    )
    shift
    shift
    goto parse_loop
)
if /I "%ARG%"=="-dns-6" (
    if "%~2"=="" goto usage_err
    if /I "%~2"=="opendns" (
        set "DNS_PROVIDER_IPV6=opendns"
        set "DNS_SPECIFIED=1"
    ) else if /I "%~2"=="cloudflare" (
        set "DNS_PROVIDER_IPV6=cloudflare"
        set "DNS_SPECIFIED=1"
    ) else (
        echo ERROR: Invalid DNS provider "%~2". Must be: opendns or cloudflare 1>&2
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
if /I "%ARG%"=="-ipv4-only" (
    if not "%IP_VERSION_FILTER%"=="" (
        echo ERROR: Cannot specify multiple IP version flags 1>&2
        goto usage_err
    )
    set "IP_VERSION_FILTER=ipv4"
    shift
    goto parse_loop
)
if /I "%ARG%"=="-ipv6-only" (
    if not "%IP_VERSION_FILTER%"=="" (
        echo ERROR: Cannot specify multiple IP version flags 1>&2
        goto usage_err
    )
    set "IP_VERSION_FILTER=ipv6"
    shift
    goto parse_loop
)
if /I "%ARG%"=="-ip-only" (
    set "IP_ONLY=1"
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

set "BASE_HOST_IPV4=%HTTPS_URL_IPV4:https://=%"
for /f "delims=/ tokens=1" %%A in ("%BASE_HOST_IPV4%") do set "BASE_HOST_IPV4=%%A"

set "BASE_HOST_IPV6=%HTTPS_URL_IPV6:https://=%"
for /f "delims=/ tokens=1" %%A in ("%BASE_HOST_IPV6%") do set "BASE_HOST_IPV6=%%A"

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
echo Usage: .\get_public_ip.bat [-timeout ^<seconds^>] [-https ^<host[/path]^>] [-https-4 ^<host[/path]^>] [-https-6 ^<host[/path]^>] [-dns ^<provider^>] [-dns-4 ^<provider^>] [-dns-6 ^<provider^>] [-https-only] [-dns-only] [-ipv4-only] [-ipv6-only] [-ip-only] [-command ^<command^>]
echo.
echo Providers (for -dns, -dns-4, -dns-6):
echo     opendns ^| cloudflare
echo Commands (for -command):
echo     curl ^| certutil ^| bitsadmin ^| nslookup
echo Modes:
echo     -https-only   Use HTTPS methods only (no DNS fallback)
echo     -dns-only     Use DNS method only (skip HTTPS)
echo     -ipv4-only    Only output IPv4 addresses
echo     -ipv6-only    Only output IPv6 addresses
echo     -ip-only      Output only IP address without metadata
echo Version-specific endpoints:
echo     -https-4      HTTPS endpoint for IPv4 (overrides -https for IPv4)
echo     -https-6      HTTPS endpoint for IPv6 (overrides -https for IPv6)
echo     -dns-4        DNS provider for IPv4 (overrides -dns for IPv4)
echo     -dns-6        DNS provider for IPv6 (overrides -dns for IPv6)
echo Notes:
echo     Supplying both -https-only and -dns-only is an error.
echo     Supplying both -ipv4-only and -ipv6-only is an error.
echo     -command forces use of exactly one retrieval tool and bypasses fallback logic.
echo     If -command is set it must not conflict with a chosen mode (e.g. forcing nslookup with -https-only).
echo     Version-specific parameters (-https-4, -https-6, -dns-4, -dns-6) override general parameters for their respective IP versions.
echo Examples:
echo     .\get_public_ip.bat -timeout 5
echo     .\get_public_ip.bat -https ipinfo.io/ip
echo     .\get_public_ip.bat -https-4 ipv4.icanhazip.com -https-6 ipv6.icanhazip.com
echo     .\get_public_ip.bat -dns cloudflare
echo     .\get_public_ip.bat -dns-4 cloudflare -dns-6 opendns
echo     .\get_public_ip.bat -dns-only -dns cloudflare
echo     .\get_public_ip.bat -https-only -https ipv4.icanhazip.com
echo     .\get_public_ip.bat -ipv4-only -ip-only
echo     .\get_public_ip.bat -ipv6-only
goto :eof


:forced_fetch
if /I "%MODE%"=="https-only" (
    if /I "%FORCED_COMMAND%"=="nslookup" (
        echo ERROR: -command nslookup conflicts with -https-only 1>&2
        goto usage_err
    )
)
if /I "%MODE%"=="dns-only" (
    if /I "%FORCED_COMMAND%"=="curl" (
        echo ERROR: -command curl conflicts with -dns-only 1>&2
        goto usage_err
    )
    if /I "%FORCED_COMMAND%"=="certutil" (
        echo ERROR: -command certutil conflicts with -dns-only 1>&2
        goto usage_err
    )
    if /I "%FORCED_COMMAND%"=="bitsadmin" (
        echo ERROR: -command bitsadmin conflicts with -dns-only 1>&2
        goto usage_err
    )
)

set "success=0"
if /I "%FORCED_COMMAND%"=="curl" (
    call :https_curl_forced && set "success=1"
) else if /I "%FORCED_COMMAND%"=="certutil" (
    call :https_certutil_forced && set "success=1"
) else if /I "%FORCED_COMMAND%"=="bitsadmin" (
    call :https_bitsadmin_forced && set "success=1"
) else if /I "%FORCED_COMMAND%"=="nslookup" (
    call :dns_nslookup_forced && set "success=1"
)

if "%success%"=="1" exit /b 0
exit /b 1


:fetch_https
set "success=0"
if "%IP_VERSION_FILTER%"=="ipv4" (
    call :try_https_ipv4 && set "success=1"
) else if "%IP_VERSION_FILTER%"=="ipv6" (
    call :try_https_ipv6 && set "success=1"
) else (
    call :try_https_ipv4 && set "success=1"
    call :try_https_ipv6 && set "success=1"
)
if "%success%"=="1" exit /b 0
exit /b 1

:try_https_ipv4
call :https_curl_ipv4 && exit /b 0
call :https_certutil_ipv4 && exit /b 0
call :https_bitsadmin_ipv4 && exit /b 0
exit /b 1

:try_https_ipv6
call :https_curl_ipv6 && exit /b 0
call :https_certutil_ipv6 && exit /b 0
call :https_bitsadmin_ipv6 && exit /b 0
exit /b 1

:https_curl_ipv4
where curl >nul 2>&1 || exit /b 1
set "URL_TO_USE=%HTTPS_URL_IPV4%"
set "HOST_TO_REPORT=%BASE_HOST_IPV4%"
for /f %%A in ('curl -ks --max-time %TIMEOUT% "!URL_TO_USE!" 2^>nul') do (
    call :validate_and_output "%%A,4,https,!HOST_TO_REPORT!,curl"
    if not errorlevel 1 exit /b 0
)
if not "!URL_TO_USE!"=="%DEFAULT_HTTPS_IPV4%" (
    for /f %%A in ('curl -ks --max-time %TIMEOUT% "%DEFAULT_HTTPS_IPV4%" 2^>nul') do (
        call :validate_and_output "%%A,4,https,ipv4.icanhazip.com,curl"
        if not errorlevel 1 exit /b 0
    )
)
exit /b 1

:https_curl_ipv6
where curl >nul 2>&1 || exit /b 1
set "URL_TO_USE=%HTTPS_URL_IPV6%"
set "HOST_TO_REPORT=%BASE_HOST_IPV6%"
for /f %%A in ('curl -6 -ks --max-time %TIMEOUT% "!URL_TO_USE!" 2^>nul') do (
    call :validate_and_output "%%A,6,https,!HOST_TO_REPORT!,curl"
    if not errorlevel 1 exit /b 0
)
if not "!URL_TO_USE!"=="%DEFAULT_HTTPS_IPV6%" (
    for /f %%A in ('curl -6 -ks --max-time %TIMEOUT% "%DEFAULT_HTTPS_IPV6%" 2^>nul') do (
        call :validate_and_output "%%A,6,https,ipv6.icanhazip.com,curl"
        if not errorlevel 1 exit /b 0
    )
)
exit /b 1

:https_certutil_ipv4
where certutil >nul 2>&1 || exit /b 1
set "URL_TO_USE=%HTTPS_URL_IPV4%"
set "HOST_TO_REPORT=%BASE_HOST_IPV4%"
set "tmpfile=%~dp0certutil_ipv4.tmp"
certutil -urlcache -split -f "!URL_TO_USE!" "!tmpfile!" >nul 2>&1
if exist "!tmpfile!" (
    for /f %%A in ('type "!tmpfile!" 2^>nul') do (
        call :validate_and_output "%%A,4,https,!HOST_TO_REPORT!,certutil"
        if not errorlevel 1 (
            del "!tmpfile!" >nul 2>&1
            exit /b 0
        )
    )
    del "!tmpfile!" >nul 2>&1
)
if not "!URL_TO_USE!"=="%DEFAULT_HTTPS_IPV4%" (
    set "tmpfile=%~dp0certutil_ipv4.tmp"
    certutil -urlcache -split -f "%DEFAULT_HTTPS_IPV4%" "!tmpfile!" >nul 2>&1
    if exist "!tmpfile!" (
        for /f %%A in ('type "!tmpfile!" 2^>nul') do (
            call :validate_and_output "%%A,4,https,ipv4.icanhazip.com,certutil"
            if not errorlevel 1 (
                del "!tmpfile!" >nul 2>&1
                exit /b 0
            )
        )
        del "!tmpfile!" >nul 2>&1
    )
)
exit /b 1

:https_certutil_ipv6
where certutil >nul 2>&1 || exit /b 1
set "URL_TO_USE=%HTTPS_URL_IPV6%"
set "HOST_TO_REPORT=%BASE_HOST_IPV6%"
set "tmpfile=%~dp0certutil_ipv6.tmp"
certutil -urlcache -split -f "!URL_TO_USE!" "!tmpfile!" >nul 2>&1
if exist "!tmpfile!" (
    for /f %%A in ('type "!tmpfile!" 2^>nul') do (
        call :validate_and_output "%%A,6,https,!HOST_TO_REPORT!,certutil"
        if not errorlevel 1 (
            del "!tmpfile!" >nul 2>&1
            exit /b 0
        )
    )
    del "!tmpfile!" >nul 2>&1
)
if not "!URL_TO_USE!"=="%DEFAULT_HTTPS_IPV6%" (
    set "tmpfile=%~dp0certutil_ipv6.tmp"
    certutil -urlcache -split -f "%DEFAULT_HTTPS_IPV6%" "!tmpfile!" >nul 2>&1
    if exist "!tmpfile!" (
        for /f %%A in ('type "!tmpfile!" 2^>nul') do (
            call :validate_and_output "%%A,6,https,ipv6.icanhazip.com,certutil"
            if not errorlevel 1 (
                del "!tmpfile!" >nul 2>&1
                exit /b 0
            )
        )
        del "!tmpfile!" >nul 2>&1
    )
)
exit /b 1

:https_bitsadmin_ipv4
where bitsadmin >nul 2>&1 || exit /b 1
set "URL_TO_USE=%HTTPS_URL_IPV4%"
set "HOST_TO_REPORT=%BASE_HOST_IPV4%"
set "tmpfile=%~dp0bitsadmin_ipv4.tmp"
bitsadmin /transfer getip "!URL_TO_USE!" "!tmpfile!" >nul 2>&1
if exist "!tmpfile!" (
    for /f %%A in ('type "!tmpfile!" 2^>nul') do (
        call :validate_and_output "%%A,4,https,!HOST_TO_REPORT!,bitsadmin"
        if not errorlevel 1 (
            del "!tmpfile!" >nul 2>&1
            exit /b 0
        )
    )
    del "!tmpfile!" >nul 2>&1
)
if not "!URL_TO_USE!"=="%DEFAULT_HTTPS_IPV4%" (
    set "tmpfile=%~dp0bitsadmin_ipv4.tmp"
    bitsadmin /transfer getip_fallback "%DEFAULT_HTTPS_IPV4%" "!tmpfile!" >nul 2>&1
    if exist "!tmpfile!" (
        for /f %%A in ('type "!tmpfile!" 2^>nul') do (
            call :validate_and_output "%%A,4,https,ipv4.icanhazip.com,bitsadmin"
            if not errorlevel 1 (
                del "!tmpfile!" >nul 2>&1
                exit /b 0
            )
        )
        del "!tmpfile!" >nul 2>&1
    )
)
exit /b 1

:https_bitsadmin_ipv6
where bitsadmin >nul 2>&1 || exit /b 1
set "URL_TO_USE=%HTTPS_URL_IPV6%"
set "HOST_TO_REPORT=%BASE_HOST_IPV6%"
set "tmpfile=%~dp0bitsadmin_ipv6.tmp"
start /B "" cmd /c "bitsadmin /transfer getip6 \"!URL_TO_USE!\" \"!tmpfile!\" >nul 2>&1"
timeout /t %TIMEOUT% /nobreak >nul 2>&1
taskkill /F /IM bitsadmin.exe /T >nul 2>&1
if exist "!tmpfile!" (
    set "bitsadmin_result=0"
) else (
    set "bitsadmin_result=1"
)
if "!bitsadmin_result!"=="0" (
    if exist "!tmpfile!" (
        for /f %%A in ('type "!tmpfile!" 2^>nul') do (
            call :validate_and_output "%%A,6,https,!HOST_TO_REPORT!,bitsadmin"
            if not errorlevel 1 (
                del "!tmpfile!" >nul 2>&1
                exit /b 0
            )
        )
        del "!tmpfile!" >nul 2>&1
    )
)
if exist "!tmpfile!" del "!tmpfile!" >nul 2>&1
if not "!URL_TO_USE!"=="%DEFAULT_HTTPS_IPV6%" (
    set "tmpfile=%~dp0bitsadmin_ipv6.tmp"
    start /B "" cmd /c "bitsadmin /transfer getip6_fallback \"!DEFAULT_HTTPS_IPV6!\" \"!tmpfile!\" >nul 2>&1"
    timeout /t %TIMEOUT% /nobreak >nul 2>&1
    taskkill /F /IM bitsadmin.exe /T >nul 2>&1
    if exist "!tmpfile!" (
        set "bitsadmin_result=0"
    ) else (
        set "bitsadmin_result=1"
    )
    if "!bitsadmin_result!"=="0" (
        if exist "!tmpfile!" (
            for /f %%A in ('type "!tmpfile!" 2^>nul') do (
                call :validate_and_output "%%A,6,https,ipv6.icanhazip.com,bitsadmin"
                if not errorlevel 1 (
                    del "!tmpfile!" >nul 2>&1
                    exit /b 0
                )
            )
            del "!tmpfile!" >nul 2>&1
        )
    )
    if exist "!tmpfile!" del "!tmpfile!" >nul 2>&1
)
exit /b 1


:fetch_dns
set "success=0"
if "%IP_VERSION_FILTER%"=="ipv4" (
    call :try_dns_ipv4 && set "success=1"
) else if "%IP_VERSION_FILTER%"=="ipv6" (
    call :try_dns_ipv6 && set "success=1"
) else (
    call :try_dns_ipv4 && set "success=1"
    call :try_dns_ipv6 && set "success=1"
)
if "%success%"=="1" exit /b 0
exit /b 1

:try_dns_ipv4
call :dns_nslookup_ipv4 && exit /b 0
exit /b 1

:try_dns_ipv6
call :dns_nslookup_ipv6 && exit /b 0
exit /b 1

:dns_nslookup_ipv4
where nslookup >nul 2>&1 || exit /b 1
if "%DNS_PROVIDER_IPV4%"=="cloudflare" (
    call :dns_cloudflare_ipv4 && exit /b 0
    call :dns_opendns_ipv4 && exit /b 0
) else (
    call :dns_opendns_ipv4 && exit /b 0
)
exit /b 1

:dns_nslookup_ipv6
where nslookup >nul 2>&1 || exit /b 1
if "%DNS_PROVIDER_IPV6%"=="cloudflare" (
    call :dns_cloudflare_ipv6 && exit /b 0
    call :dns_opendns_ipv6 && exit /b 0
) else (
    call :dns_opendns_ipv6 && exit /b 0
)
exit /b 1

:dns_opendns_ipv4
for /f "skip=3 tokens=2 delims=: " %%A in ('nslookup myip.opendns.com resolver4.opendns.com 2^>nul') do (
    set "ip=%%A"
    set "ip=!ip: =!"
    call :validate_and_output "!ip!,4,dns,opendns,nslookup"
    if not errorlevel 1 exit /b 0
)
exit /b 1

:dns_opendns_ipv6
setlocal
set "tmp=%~dp0opendns_ipv6.tmp"
nslookup -type=AAAA myip.opendns.com resolver1.opendns.com 2>nul | findstr "Address:" > "%tmp%"
for /f "usebackq tokens=2 delims= " %%A in ("%tmp%") do (
    set "last_ip=%%A"
)
if not "!last_ip!"=="" (
    call :validate_and_output "!last_ip!,6,dns,opendns,nslookup"
    if not errorlevel 1 (
        del "%tmp%" >nul 2>&1
        endlocal
        exit /b 0
    )
)
del "%tmp%" >nul 2>&1
endlocal
exit /b 1

:dns_cloudflare_ipv4
setlocal
set "tmp=%~dp0cloudflare_ipv4.tmp"
nslookup -class=CHAOS -q=TXT whoami.cloudflare 1.1.1.1 2>nul | findstr /r /c:"\"[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\"" > "%tmp%"
for /f "usebackq delims=" %%A in ("%tmp%") do (set "line=%%A" & goto :cloudflare_ipv4_process)
:cloudflare_ipv4_process
set "line=!line:"=!"
for /f "tokens=*" %%C in ("!line!") do set "line=%%C"
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

:dns_cloudflare_ipv6
setlocal
set "tmp=%~dp0cloudflare_ipv6.tmp"
nslookup -class=CHAOS -q=TXT whoami.cloudflare 2606:4700:4700::1111 2>nul | findstr /r /c:"\"[0-9a-fA-F:]*:.*\"" > "%tmp%"
for /f "usebackq delims=" %%A in ("%tmp%") do (set "line=%%A" & goto :cloudflare_ipv6_process)
:cloudflare_ipv6_process
set "line=!line:"=!"
for /f "tokens=*" %%C in ("!line!") do set "line=%%C"
call :validate_and_output "!line!,6,dns,cloudflare,nslookup"
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
exit /b 1


:validate_and_output
setlocal
set "result=%~1"

for /f "tokens=1,2 delims=," %%A in ("%result%") do (
    set "ip_part=%%A"
    set "ip_version=%%B"
)

set "ip_part=!ip_part:"=!"

set "is_valid=0"
if "!ip_version!"=="4" (
    echo !ip_part! | findstr /r "[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*" >nul
    if not errorlevel 1 (
        for /f "tokens=1,2,3,4 delims=." %%A in ("!ip_part!") do (
            if %%A leq 255 if %%B leq 255 if %%C leq 255 if %%D leq 255 (
                set "is_valid=1"
            )
        )
    )
) else if "!ip_version!"=="6" (
    echo !ip_part! | findstr /r "[0-9a-fA-F:][0-9a-fA-F:]*" >nul
    if not errorlevel 1 (
        echo !ip_part! | findstr ":" >nul
        if not errorlevel 1 (
            set "colon_count=0"
            set "temp_ip=!ip_part!"
            :count_colons
            if "!temp_ip!"=="" goto done_counting
            if "!temp_ip:~0,1!"==":" set /a colon_count+=1
            set "temp_ip=!temp_ip:~1!"
            goto count_colons
            :done_counting
            if !colon_count! geq 2 if !colon_count! leq 7 (
                set "is_valid=1"
            )
        )
    )
)

if "!is_valid!"=="1" (
    if "%IP_ONLY%"=="1" (
        echo !ip_part!
    ) else (
        echo !result!
    )
    endlocal
    exit /b 0
)
endlocal
exit /b 1

:https_curl_forced
where curl >nul 2>&1 || exit /b 1
set "success=0"
if "%IP_VERSION_FILTER%"=="ipv4" (
    call :https_curl_ipv4 && set "success=1"
) else if "%IP_VERSION_FILTER%"=="ipv6" (
    call :https_curl_ipv6 && set "success=1"
) else (
    call :https_curl_ipv4 && set "success=1"
    call :https_curl_ipv6 && set "success=1"
)
if "%success%"=="1" exit /b 0
exit /b 1

:https_certutil_forced
where certutil >nul 2>&1 || exit /b 1
set "success=0"
if "%IP_VERSION_FILTER%"=="ipv4" (
    call :https_certutil_ipv4 && set "success=1"
) else if "%IP_VERSION_FILTER%"=="ipv6" (
    call :https_certutil_ipv6 && set "success=1"
) else (
    call :https_certutil_ipv4 && set "success=1"
    call :https_certutil_ipv6 && set "success=1"
)
if "%success%"=="1" exit /b 0
exit /b 1

:https_bitsadmin_forced
where bitsadmin >nul 2>&1 || exit /b 1
set "success=0"
if "%IP_VERSION_FILTER%"=="ipv4" (
    call :https_bitsadmin_ipv4 && set "success=1"
) else if "%IP_VERSION_FILTER%"=="ipv6" (
    call :https_bitsadmin_ipv6 && set "success=1"
) else (
    call :https_bitsadmin_ipv4 && set "success=1"
    call :https_bitsadmin_ipv6 && set "success=1"
)
if "%success%"=="1" exit /b 0
exit /b 1

:dns_nslookup_forced
where nslookup >nul 2>&1 || exit /b 1
set "success=0"
if "%IP_VERSION_FILTER%"=="ipv4" (
    call :dns_nslookup_ipv4 && set "success=1"
) else if "%IP_VERSION_FILTER%"=="ipv6" (
    call :dns_nslookup_ipv6 && set "success=1"
) else (
    call :dns_nslookup_ipv4 && set "success=1"
    call :dns_nslookup_ipv6 && set "success=1"
)
if "%success%"=="1" exit /b 0
exit /b 1
