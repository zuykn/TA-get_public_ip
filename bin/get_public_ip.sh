#!/bin/sh

# Script: get_public_ip.sh
# Author: zuykn.io
# Copyright 2023-2025 zuykn
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -e

TIMEOUT=10
HTTPS_URL="https://checkip.amazonaws.com"
DNS_PROVIDER="opendns"
MODE="auto"
FORCED_COMMAND=""
SCRIPT_NAME=$(basename "$0")

usage() {
    code="${1:-1}"
    cat <<EOF 1>&2
Usage: ./$SCRIPT_NAME [-timeout <seconds>] [-https <host[/path]>] [-dns <provider>] [-https-only] [-dns-only] [-command <command>]

Providers (for -dns):
    opendns | google | cloudflare
Commands (for -command):
    curl | wget | dig | nslookup
Modes:
    -https-only   Use HTTPS methods only (no DNS fallback)
    -dns-only     Use DNS method only (skip HTTPS)
Notes:
    Supplying both -https-only and -dns-only is an error.
    -command forces use of exactly one retrieval tool and bypasses fallback logic.
    If -command is set it must not conflict with a chosen mode (e.g. forcing dig with -https-only).
Examples:
    ./$SCRIPT_NAME -timeout 5
    ./$SCRIPT_NAME -https ipinfo.io/ip
    ./$SCRIPT_NAME -dns cloudflare
    ./$SCRIPT_NAME -dns-only -dns google
    ./$SCRIPT_NAME -https-only -https checkip.amazonaws.com
EOF
    exit "$code"
}

is_int() { [ "$1" -eq "$1" ] 2>/dev/null; }

while [ $# -gt 0 ]; do
    case "$1" in
        -timeout)
            shift || usage
            is_int "$1" && [ "$1" -gt 0 ] || usage
            TIMEOUT=$1
            ;;
        -https)
            shift || usage
            case "$1" in
                https://*) HTTPS_URL="$1" ;;
                http://*) echo "ERROR: Only HTTPS is allowed (omit scheme to auto-prepend https://)" 1>&2; usage ;;
                */*) HTTPS_URL="https://$1" ;;
                *) HTTPS_URL="https://$1" ;;
            esac
            ;;
        -dns)
            shift || usage
            provider_lc=$(printf '%s' "$1" | tr 'A-Z' 'a-z')
            case "$provider_lc" in
                opendns|google|cloudflare) DNS_PROVIDER="$provider_lc" ;;
                *) usage ;;
            esac
            _DNS_FLAG_SET=1
            ;;
        -https-only)
            [ "$MODE" = "auto" ] || { echo "ERROR: multiple mode flags" 1>&2; usage; }
            MODE="https-only"
            ;;
        -dns-only)
            [ "$MODE" = "auto" ] || { echo "ERROR: multiple mode flags" 1>&2; usage; }
            MODE="dns-only"
            ;;
        -command)
            shift || usage
            case "$1" in curl|wget|dig|nslookup) FORCED_COMMAND="$1" ;; *) usage ;; esac
            ;;
        -h|-help|--help)
            usage 0
            ;;
        *)
            echo "ERROR: Unknown flag: $1" 1>&2
            usage
            ;;
    esac
    shift
done

if [ -n "$FORCED_COMMAND" ]; then
    case "$MODE" in
        https-only)
            case "$FORCED_COMMAND" in dig|nslookup)
                echo "ERROR: -command $FORCED_COMMAND conflicts with -https-only" 1>&2; usage ;;
            esac
            ;;
        dns-only)
            case "$FORCED_COMMAND" in curl|wget)
                echo "ERROR: -command $FORCED_COMMAND conflicts with -dns-only" 1>&2; usage ;;
            esac
            ;;
    esac
fi

BASE_HOST=$(printf '%s' "$HTTPS_URL" | sed -E 's#^https://([^/]+)/?.*#\1#')

https_query_curl() {
    url="$1"
    unset LD_LIBRARY_PATH
    curl -ks --max-time "$TIMEOUT" "$url" 2>/dev/null | tr -d '\r' | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1
}

https_query_wget() {
    url="$1"
    wget -qO- --timeout="$TIMEOUT" "$url" 2>/dev/null | tr -d '\r' | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1
}

try_https_with_fallback() {
    tool="$1"
    case "$tool" in
        curl)
            command -v curl >/dev/null 2>&1 || return 1
            ip=$(https_query_curl "$HTTPS_URL")
            [ -n "$ip" ] && { validate_and_output "$ip,4,https,$BASE_HOST,curl" && return 0; }
            
            if [ "$HTTPS_URL" != "https://checkip.amazonaws.com" ]; then
                ip=$(https_query_curl "https://checkip.amazonaws.com")
                [ -n "$ip" ] && { validate_and_output "$ip,4,https,checkip.amazonaws.com,curl" && return 0; }
            fi
            ;;
        wget)
            command -v wget >/dev/null 2>&1 || return 1
            ip=$(https_query_wget "$HTTPS_URL")
            [ -n "$ip" ] && { validate_and_output "$ip,4,https,$BASE_HOST,wget" && return 0; }
            
            if [ "$HTTPS_URL" != "https://checkip.amazonaws.com" ]; then
                ip=$(https_query_wget "https://checkip.amazonaws.com")
                [ -n "$ip" ] && { validate_and_output "$ip,4,https,checkip.amazonaws.com,wget" && return 0; }
            fi
            ;;
    esac
    return 1
}

https_fetch() {
    try_https_with_fallback "curl" && return 0
    try_https_with_fallback "wget" && return 0
    return 1
}

dns_query_dig() {
    provider="$1"
    case "$provider" in
        opendns) dig +short myip.opendns.com @resolver1.opendns.com 2>/dev/null | head -1 ;;
        google) dig +short TXT o-o.myaddr.l.google.com @ns1.google.com 2>/dev/null | tr -d '"' | head -1 ;;
        cloudflare) dig +short @1.1.1.1 whoami.cloudflare CH TXT 2>/dev/null | tr -d '"' | head -1 ;;
    esac
}

dns_query_nslookup() {
    provider="$1"
    case "$provider" in
        opendns) nslookup myip.opendns.com resolver1.opendns.com 2>/dev/null | grep -Eo 'Address:[[:space:]]*[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | awk '{print $2}' | tail -1 ;;
        google) nslookup -type=txt o-o.myaddr.l.google.com ns1.google.com 2>/dev/null | awk -F'"' '/text/ {print $2}' | head -1 ;;
        cloudflare) nslookup -class=CHAOS -q=TXT whoami.cloudflare 1.1.1.1 2>/dev/null | awk -F'"' '/text/ {print $2}' | head -1 ;;
    esac
}

dns_fetch() {
    if command -v dig >/dev/null 2>&1; then
        ip=$(dns_query_dig "$DNS_PROVIDER")
        [ -n "$ip" ] && { validate_and_output "$ip,4,dns,$DNS_PROVIDER,dig" && return 0; }
        
        if [ "$DNS_PROVIDER" != "opendns" ]; then
            ip=$(dns_query_dig "opendns")
            [ -n "$ip" ] && { validate_and_output "$ip,4,dns,opendns,dig" && return 0; }
        fi
    fi
    
    if command -v nslookup >/dev/null 2>&1; then
        ip=$(dns_query_nslookup "$DNS_PROVIDER")
        [ -n "$ip" ] && { validate_and_output "$ip,4,dns,$DNS_PROVIDER,nslookup" && return 0; }
        
        if [ "$DNS_PROVIDER" != "opendns" ]; then
            ip=$(dns_query_nslookup "opendns")
            [ -n "$ip" ] && { validate_and_output "$ip,4,dns,opendns,nslookup" && return 0; }
        fi
    fi
    return 1
}

fail() {
    echo ""
    exit 1
}

forced_fetch() {
    case "$FORCED_COMMAND" in
        curl|wget)
            try_https_with_fallback "$FORCED_COMMAND" && return 0
            ;;
        dig)
            command -v dig >/dev/null 2>&1 || return 1
            ip=$(dns_query_dig "$DNS_PROVIDER")
            [ -n "$ip" ] && { validate_and_output "$ip,4,dns,$DNS_PROVIDER,dig" && return 0; }
            if [ "$DNS_PROVIDER" != "opendns" ]; then
                ip=$(dns_query_dig "opendns")
                [ -n "$ip" ] && { validate_and_output "$ip,4,dns,opendns,dig" && return 0; }
            fi
            ;;
        nslookup)
            command -v nslookup >/dev/null 2>&1 || return 1
            ip=$(dns_query_nslookup "$DNS_PROVIDER")
            [ -n "$ip" ] && { validate_and_output "$ip,4,dns,$DNS_PROVIDER,nslookup" && return 0; }
            if [ "$DNS_PROVIDER" != "opendns" ]; then
                ip=$(dns_query_nslookup "opendns")
                [ -n "$ip" ] && { validate_and_output "$ip,4,dns,opendns,nslookup" && return 0; }
            fi
            ;;
        *)
            return 1
            ;;
    esac
    return 1
}

validate_and_output() {
    result="$1"
    ip_part=$(echo "$result" | cut -d',' -f1)
    if echo "$ip_part" | grep -E '^([0-9]{1,3}\.){3}[0-9]{1,3}$' >/dev/null 2>&1; then
        for octet in $(echo "$ip_part" | tr '.' ' '); do
            [ "$octet" -gt 255 ] 2>/dev/null && return 1
        done
        echo "$result"
        return 0
    fi
    return 1
}

USER_SET_DNS_FLAG=0
[ -n "${_DNS_FLAG_SET:-}" ] && USER_SET_DNS_FLAG=1

if [ -n "$FORCED_COMMAND" ]; then
    forced_fetch || fail
else
    case "$MODE" in
        https-only)
            https_fetch || fail
            ;;
        dns-only)
            dns_fetch || fail
            ;;
        auto)
            if [ $USER_SET_DNS_FLAG -eq 1 ]; then
                if ! dns_fetch; then
                    https_fetch || fail
                fi
            else
                if ! https_fetch; then
                    dns_fetch || fail
                fi
            fi
            ;;
        *)
            echo "ERROR: invalid mode state" 1>&2
            fail
            ;;
    esac
fi

exit 0
