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

DEFAULT_HTTPS_IPV4="https://ipv4.icanhazip.com"
DEFAULT_HTTPS_IPV6="https://ipv6.icanhazip.com"
DEFAULT_DNS_PROVIDER="opendns"

TIMEOUT=5
HTTPS_URL="$DEFAULT_HTTPS_IPV4"
HTTPS_URL_IPV4="$DEFAULT_HTTPS_IPV4"
HTTPS_URL_IPV6="$DEFAULT_HTTPS_IPV6"
DNS_PROVIDER="$DEFAULT_DNS_PROVIDER"
DNS_PROVIDER_IPV4="$DEFAULT_DNS_PROVIDER"
DNS_PROVIDER_IPV6="$DEFAULT_DNS_PROVIDER"
MODE="auto"
FORCED_COMMAND=""
IP_ONLY=0
IP_VERSION_FILTER=""
SCRIPT_NAME=$(basename "$0")

usage() {
    code="${1:-1}"
    cat <<EOF 1>&2
Usage: ./$SCRIPT_NAME [-timeout <seconds>] [-https <host[/path]>] [-https-4 <host[/path]>] [-https-6 <host[/path]>] [-dns <provider>] [-dns-4 <provider>] [-dns-6 <provider>] [-https-only] [-dns-only] [-ipv4-only] [-ipv6-only] [-ip-only] [-command <command>]

Providers (for -dns, -dns-4, -dns-6):
    opendns | cloudflare
Commands (for -command):
    curl | wget | dig | nslookup
Modes:
    -https-only   Use HTTPS methods only (no DNS fallback)
    -dns-only     Use DNS method only (skip HTTPS)
    -ipv4-only    Only output IPv4 addresses
    -ipv6-only    Only output IPv6 addresses
    -ip-only      Output only IP address without metadata
Version-specific endpoints:
    -https-4      HTTPS endpoint for IPv4 (overrides -https for IPv4)
    -https-6      HTTPS endpoint for IPv6 (overrides -https for IPv6)
    -dns-4        DNS provider for IPv4 (overrides -dns for IPv4)
    -dns-6        DNS provider for IPv6 (overrides -dns for IPv6)
Notes:
    Supplying both -https-only and -dns-only is an error.
    Supplying both -ipv4-only and -ipv6-only is an error.
    -command forces use of exactly one retrieval tool and bypasses fallback logic.
    If -command is set it must not conflict with a chosen mode (e.g. forcing dig with -https-only).
    Version-specific parameters (-https-4, -https-6, -dns-4, -dns-6) override general parameters for their respective IP versions.
Examples:
    ./$SCRIPT_NAME -timeout 5
    ./$SCRIPT_NAME -https ipinfo.io/ip
    ./$SCRIPT_NAME -https-4 ipv4.icanhazip.com -https-6 ipv6.icanhazip.com
    ./$SCRIPT_NAME -dns cloudflare
    ./$SCRIPT_NAME -dns-4 cloudflare -dns-6 opendns
    ./$SCRIPT_NAME -dns-only -dns cloudflare
    ./$SCRIPT_NAME -https-only -https ipv4.icanhazip.com
    ./$SCRIPT_NAME -ipv4-only -ip-only
    ./$SCRIPT_NAME -ipv6-only
EOF
    exit "$code"
}

is_int() { [ "$1" -eq "$1" ] 2>/dev/null; }

while [ $# -gt 0 ]; do
    case "$1" in
        -timeout)
            shift || { echo "ERROR: -timeout requires a value" 1>&2; usage; }
            [ -z "$1" ] && { echo "ERROR: -timeout cannot be empty" 1>&2; usage; }
            if ! is_int "$1"; then
                echo "ERROR: timeout must be a positive integer, got: $1" 1>&2; usage;
            fi
            if [ "$1" -le 0 ]; then
                echo "ERROR: timeout must be greater than 0, got: $1" 1>&2; usage;
            fi
            TIMEOUT=$1
            ;;
        -https)
            shift || { echo "ERROR: -https requires a URL" 1>&2; usage; }
            [ -z "$1" ] && { echo "ERROR: -https URL cannot be empty" 1>&2; usage; }
            case "$1" in
                https://*) HTTPS_URL="$1" ;;
                http://*) echo "ERROR: Only HTTPS is allowed (omit scheme to auto-prepend https://)" 1>&2; usage ;;
                */*) HTTPS_URL="https://$1" ;;
                *) HTTPS_URL="https://$1" ;;
            esac
            ;;
        -https-4)
            shift || { echo "ERROR: -https-4 requires a URL" 1>&2; usage; }
            [ -z "$1" ] && { echo "ERROR: -https-4 URL cannot be empty" 1>&2; usage; }
            case "$1" in
                https://*) HTTPS_URL_IPV4="$1" ;;
                http://*) echo "ERROR: Only HTTPS is allowed (omit scheme to auto-prepend https://)" 1>&2; usage ;;
                */*) HTTPS_URL_IPV4="https://$1" ;;
                *) HTTPS_URL_IPV4="https://$1" ;;
            esac
            ;;
        -https-6)
            shift || { echo "ERROR: -https-6 requires a URL" 1>&2; usage; }
            [ -z "$1" ] && { echo "ERROR: -https-6 URL cannot be empty" 1>&2; usage; }
            case "$1" in
                https://*) HTTPS_URL_IPV6="$1" ;;
                http://*) echo "ERROR: Only HTTPS is allowed (omit scheme to auto-prepend https://)" 1>&2; usage ;;
                */*) HTTPS_URL_IPV6="https://$1" ;;
                *) HTTPS_URL_IPV6="https://$1" ;;
            esac
            ;;
        -dns)
            shift || { echo "ERROR: -dns requires a provider name" 1>&2; usage; }
            [ -z "$1" ] && { echo "ERROR: -dns provider cannot be empty" 1>&2; usage; }
            provider_lc=$(printf '%s' "$1" | tr 'A-Z' 'a-z')
            case "$provider_lc" in
                opendns|cloudflare) DNS_PROVIDER="$provider_lc" ;;
                *) DNS_PROVIDER="$DEFAULT_DNS_PROVIDER" ;;
            esac
            _DNS_FLAG_SET=1
            ;;
        -dns-4)
            shift || { echo "ERROR: -dns-4 requires a provider name" 1>&2; usage; }
            [ -z "$1" ] && { echo "ERROR: -dns-4 provider cannot be empty" 1>&2; usage; }
            provider_lc=$(printf '%s' "$1" | tr 'A-Z' 'a-z')
            case "$provider_lc" in
                opendns|cloudflare) DNS_PROVIDER_IPV4="$provider_lc" ;;
                *) DNS_PROVIDER_IPV4="$DEFAULT_DNS_PROVIDER" ;;
            esac
            _DNS_FLAG_SET=1
            ;;
        -dns-6)
            shift || { echo "ERROR: -dns-6 requires a provider name" 1>&2; usage; }
            [ -z "$1" ] && { echo "ERROR: -dns-6 provider cannot be empty" 1>&2; usage; }
            provider_lc=$(printf '%s' "$1" | tr 'A-Z' 'a-z')
            case "$provider_lc" in
                opendns|cloudflare) DNS_PROVIDER_IPV6="$provider_lc" ;;
                *) DNS_PROVIDER_IPV6="$DEFAULT_DNS_PROVIDER" ;;
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
        -ipv4-only)
            [ -z "$IP_VERSION_FILTER" ] || { echo "ERROR: multiple IP version flags" 1>&2; usage; }
            IP_VERSION_FILTER="ipv4"
            ;;
        -ipv6-only)
            [ -z "$IP_VERSION_FILTER" ] || { echo "ERROR: multiple IP version flags" 1>&2; usage; }
            IP_VERSION_FILTER="ipv6"
            ;;
        -ip-only)
            IP_ONLY=1
            ;;
        -command)
            shift || { echo "ERROR: -command requires a tool name" 1>&2; usage; }
            [ -z "$1" ] && { echo "ERROR: -command tool cannot be empty" 1>&2; usage; }
            case "$1" in 
                curl|wget|dig|nslookup) FORCED_COMMAND="$1" ;; 
                *) echo "ERROR: Unknown command '$1'. Valid commands: curl, wget, dig, nslookup" 1>&2; usage ;; 
            esac
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
BASE_HOST_IPV4=""
BASE_HOST_IPV6=""
[ -n "$HTTPS_URL_IPV4" ] && [ "$HTTPS_URL_IPV4" != "$DEFAULT_HTTPS_IPV4" ] && BASE_HOST_IPV4=$(printf '%s' "$HTTPS_URL_IPV4" | sed -E 's#^https://([^/]+)/?.*#\1#')
[ -n "$HTTPS_URL_IPV6" ] && [ "$HTTPS_URL_IPV6" != "$DEFAULT_HTTPS_IPV6" ] && BASE_HOST_IPV6=$(printf '%s' "$HTTPS_URL_IPV6" | sed -E 's#^https://([^/]+)/?.*#\1#')

https_query_curl() {
    url="$1"
    ip_version="$2"
    [ -z "$url" ] && return 1
    [ -z "$ip_version" ] && return 1
    unset LD_LIBRARY_PATH
    if [ "$ip_version" = "6" ]; then
        curl -6 -ks --max-time "$TIMEOUT" "$url" 2>/dev/null | tr -d '\r' | grep -Eo '([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}' | head -1
    else
        curl -ks --max-time "$TIMEOUT" "$url" 2>/dev/null | tr -d '\r' | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1
    fi
}

https_query_wget() {
    url="$1"
    ip_version="$2"
    [ -z "$url" ] && return 1
    [ -z "$ip_version" ] && return 1
    if [ "$ip_version" = "6" ]; then
        wget -6 -qO- --timeout="$TIMEOUT" "$url" 2>/dev/null | tr -d '\r' | grep -Eo '([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}' | head -1
    else
        wget -qO- --timeout="$TIMEOUT" "$url" 2>/dev/null | tr -d '\r' | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1
    fi
}

try_https_tool() {
    tool="$1"
    ip_version="$2"
    
    if [ "$ip_version" = "6" ]; then
        if [ -n "$HTTPS_URL_IPV6" ] && [ "$HTTPS_URL_IPV6" != "$DEFAULT_HTTPS_IPV6" ]; then
            if [ "$tool" = "curl" ]; then
                ip=$(https_query_curl "$HTTPS_URL_IPV6" "$ip_version")
            else
                ip=$(https_query_wget "$HTTPS_URL_IPV6" "$ip_version")
            fi
            [ -n "$ip" ] && { validate_and_output "$ip,$ip_version,https,$BASE_HOST_IPV6,$tool"; return 0; }
            if [ "$HTTPS_URL_IPV6" != "$DEFAULT_HTTPS_IPV6" ]; then
                if [ "$tool" = "curl" ]; then
                    ip=$(https_query_curl "$DEFAULT_HTTPS_IPV6" "$ip_version")
                else
                    ip=$(https_query_wget "$DEFAULT_HTTPS_IPV6" "$ip_version")
                fi
                [ -n "$ip" ] && { validate_and_output "$ip,$ip_version,https,ipv6.icanhazip.com,$tool"; return 0; }
            fi
        else
            if [ "$tool" = "curl" ]; then
                ip=$(https_query_curl "$DEFAULT_HTTPS_IPV6" "$ip_version")
            else
                ip=$(https_query_wget "$DEFAULT_HTTPS_IPV6" "$ip_version")
            fi
            [ -n "$ip" ] && { validate_and_output "$ip,$ip_version,https,ipv6.icanhazip.com,$tool"; return 0; }
        fi
    else
        url_to_use="$HTTPS_URL"
        host_to_report="$BASE_HOST"
        if [ -n "$HTTPS_URL_IPV4" ] && [ "$HTTPS_URL_IPV4" != "$DEFAULT_HTTPS_IPV4" ]; then
            url_to_use="$HTTPS_URL_IPV4"
            host_to_report="$BASE_HOST_IPV4"
        fi
        
        if [ "$tool" = "curl" ]; then
            ip=$(https_query_curl "$url_to_use" "$ip_version")
        else
            ip=$(https_query_wget "$url_to_use" "$ip_version")
        fi
        [ -n "$ip" ] && { validate_and_output "$ip,$ip_version,https,$host_to_report,$tool"; return 0; }
        
        if [ -n "$HTTPS_URL_IPV4" ] && [ "$HTTPS_URL_IPV4" != "$DEFAULT_HTTPS_IPV4" ]; then
            if [ "$tool" = "curl" ]; then
                ip=$(https_query_curl "$DEFAULT_HTTPS_IPV4" "$ip_version")
            else
                ip=$(https_query_wget "$DEFAULT_HTTPS_IPV4" "$ip_version")
            fi
            [ -n "$ip" ] && { validate_and_output "$ip,$ip_version,https,ipv4.icanhazip.com,$tool"; return 0; }
        elif [ -z "$HTTPS_URL_IPV4" ] && [ "$HTTPS_URL" != "$DEFAULT_HTTPS_IPV4" ]; then
            if [ "$tool" = "curl" ]; then
                ip=$(https_query_curl "$DEFAULT_HTTPS_IPV4" "$ip_version")
            else
                ip=$(https_query_wget "$DEFAULT_HTTPS_IPV4" "$ip_version")
            fi
            [ -n "$ip" ] && { validate_and_output "$ip,$ip_version,https,ipv4.icanhazip.com,$tool"; return 0; }
        fi
    fi
    return 1
}

try_https_with_fallback() {
    tool="$1"
    ip_version="$2"
    case "$tool" in
        curl)
            command -v curl >/dev/null 2>&1 || return 1
            try_https_tool "curl" "$ip_version" && return 0
            ;;
        wget)
            command -v wget >/dev/null 2>&1 || return 1
            try_https_tool "wget" "$ip_version" && return 0
            ;;
    esac
    return 1
}

https_fetch() {
    success=0
    ipv4_attempted=0
    ipv6_attempted=0
    
    if [ -z "$IP_VERSION_FILTER" ]; then
        if command -v curl >/dev/null 2>&1; then
            try_https_tool "curl" "4" && ipv4_attempted=1 && success=1
            try_https_tool "curl" "6" && ipv6_attempted=1 && success=1
        fi
        if [ $ipv4_attempted -eq 0 ] && command -v wget >/dev/null 2>&1; then
            try_https_tool "wget" "4" && success=1
        fi
        if [ $ipv6_attempted -eq 0 ] && command -v wget >/dev/null 2>&1; then
            try_https_tool "wget" "6" && success=1
        fi
    elif [ "$IP_VERSION_FILTER" = "ipv4" ]; then
        if try_https_with_fallback "curl" "4" || try_https_with_fallback "wget" "4"; then
            success=1
        fi
    elif [ "$IP_VERSION_FILTER" = "ipv6" ]; then
        if try_https_with_fallback "curl" "6" || try_https_with_fallback "wget" "6"; then
            success=1
        fi
    fi
    [ $success -eq 1 ] && return 0
    return 1
}

dns_query_dig() {
    provider="$1"
    ip_version="$2"
    [ -z "$provider" ] && return 1
    [ -z "$ip_version" ] && return 1
    case "$provider" in
        opendns) 
            if [ "$ip_version" = "6" ]; then
                dig -6 +short myip.opendns.com AAAA @resolver1.opendns.com 2>/dev/null | head -1
            else
                dig -4 +short myip.opendns.com A @resolver4.opendns.com 2>/dev/null | head -1
            fi
            ;;
        cloudflare)
            if [ "$ip_version" = "6" ]; then
                dig -6 +short @2606:4700:4700::1111 whoami.cloudflare CH TXT 2>/dev/null | tr -d '"' | grep -v '^;;' | head -1
            else
                dig -4 +short @1.1.1.1 whoami.cloudflare CH TXT 2>/dev/null | tr -d '"' | head -1
            fi
            ;;
    esac
}

dns_query_nslookup() {
    provider="$1"
    ip_version="$2"
    [ -z "$provider" ] && return 1
    [ -z "$ip_version" ] && return 1
    case "$provider" in
        opendns)
            if [ "$ip_version" = "6" ]; then
                nslookup -type=AAAA -timeout=$TIMEOUT myip.opendns.com resolver1.opendns.com 2>/dev/null | grep -Eo 'Address:[[:space:]]*[0-9a-fA-F:]+' | awk '{print $2}' | tail -1
            else
                nslookup -type=A -timeout=$TIMEOUT myip.opendns.com resolver4.opendns.com 2>/dev/null | grep -Eo 'Address:[[:space:]]*[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | awk '{print $2}' | tail -1
            fi
            ;;
        cloudflare)
            if [ "$ip_version" = "6" ]; then
                nslookup -class=CHAOS -q=TXT -timeout=$TIMEOUT whoami.cloudflare 2606:4700:4700::1111 2>/dev/null | awk -F'"' '/text/ {print $2}' | head -1
            else
                nslookup -class=CHAOS -q=TXT -timeout=$TIMEOUT whoami.cloudflare 1.1.1.1 2>/dev/null | awk -F'"' '/text/ {print $2}' | head -1
            fi
            ;;
    esac
}

get_dns_provider() {
    ip_version="$1"
    if [ "$ip_version" = "4" ]; then
        [ -n "$DNS_PROVIDER_IPV4" ] && [ "$DNS_PROVIDER_IPV4" != "$DEFAULT_DNS_PROVIDER" ] && echo "$DNS_PROVIDER_IPV4" || echo "$DNS_PROVIDER"
    else
        [ -n "$DNS_PROVIDER_IPV6" ] && [ "$DNS_PROVIDER_IPV6" != "$DEFAULT_DNS_PROVIDER" ] && echo "$DNS_PROVIDER_IPV6" || echo "$DNS_PROVIDER"
    fi
}

try_dns_query() {
    tool="$1"
    provider="$2"
    ip_version="$3"
    
    if [ "$tool" = "dig" ]; then
        ip=$(dns_query_dig "$provider" "$ip_version")
    else
        ip=$(dns_query_nslookup "$provider" "$ip_version")
    fi
    
    if [ -n "$ip" ]; then
        validate_and_output "$ip,$ip_version,dns,$provider,$tool"
        return 0
    fi
    return 1
}

dns_fetch() {
    success=0
    
    if [ -z "$IP_VERSION_FILTER" ]; then
        provider_to_use=$(get_dns_provider "4")
        if command -v dig >/dev/null 2>&1; then
            try_dns_query "dig" "$provider_to_use" "4" && success=1
        elif command -v nslookup >/dev/null 2>&1; then
            try_dns_query "nslookup" "$provider_to_use" "4" && success=1
        fi
        if [ $success -eq 0 ] && [ "$provider_to_use" != "$DEFAULT_DNS_PROVIDER" ]; then
            if command -v dig >/dev/null 2>&1; then
                try_dns_query "dig" "$DEFAULT_DNS_PROVIDER" "4" && success=1
            elif command -v nslookup >/dev/null 2>&1; then
                try_dns_query "nslookup" "$DEFAULT_DNS_PROVIDER" "4" && success=1
            fi
        fi
        
        provider_to_use=$(get_dns_provider "6")
        ipv6_success=0
        if command -v dig >/dev/null 2>&1; then
            try_dns_query "dig" "$provider_to_use" "6" && { success=1; ipv6_success=1; }
        elif command -v nslookup >/dev/null 2>&1; then
            try_dns_query "nslookup" "$provider_to_use" "6" && { success=1; ipv6_success=1; }
        fi
        if [ $ipv6_success -eq 0 ] && [ "$provider_to_use" != "$DEFAULT_DNS_PROVIDER" ]; then
            if command -v dig >/dev/null 2>&1; then
                try_dns_query "dig" "$DEFAULT_DNS_PROVIDER" "6" && success=1
            elif command -v nslookup >/dev/null 2>&1; then
                try_dns_query "nslookup" "$DEFAULT_DNS_PROVIDER" "6" && success=1
            fi
        fi
    elif [ "$IP_VERSION_FILTER" = "ipv4" ]; then
        provider_to_use=$(get_dns_provider "4")
        if command -v dig >/dev/null 2>&1; then
            try_dns_query "dig" "$provider_to_use" "4" && success=1
        fi
        if [ $success -eq 0 ] && command -v nslookup >/dev/null 2>&1; then
            try_dns_query "nslookup" "$provider_to_use" "4" && success=1
        fi
        if [ $success -eq 0 ] && [ "$provider_to_use" != "$DEFAULT_DNS_PROVIDER" ]; then
            if command -v dig >/dev/null 2>&1; then
                try_dns_query "dig" "$DEFAULT_DNS_PROVIDER" "4" && success=1
            fi
            if [ $success -eq 0 ] && command -v nslookup >/dev/null 2>&1; then
                try_dns_query "nslookup" "$DEFAULT_DNS_PROVIDER" "4" && success=1
            fi
        fi
    elif [ "$IP_VERSION_FILTER" = "ipv6" ]; then
        provider_to_use=$(get_dns_provider "6")
        if command -v dig >/dev/null 2>&1; then
            try_dns_query "dig" "$provider_to_use" "6" && success=1
        fi
        if [ $success -eq 0 ] && command -v nslookup >/dev/null 2>&1; then
            try_dns_query "nslookup" "$provider_to_use" "6" && success=1
        fi
        if [ $success -eq 0 ] && [ "$provider_to_use" != "$DEFAULT_DNS_PROVIDER" ]; then
            if command -v dig >/dev/null 2>&1; then
                try_dns_query "dig" "$DEFAULT_DNS_PROVIDER" "6" && success=1
            fi
            if [ $success -eq 0 ] && command -v nslookup >/dev/null 2>&1; then
                try_dns_query "nslookup" "$DEFAULT_DNS_PROVIDER" "6" && success=1
            fi
        fi
    fi
    
    [ $success -eq 1 ] && return 0
    return 1
}

fail() {
    echo ""
    exit 1
}

forced_fetch() {
    success=0
    case "$FORCED_COMMAND" in
        curl|wget)
            command -v "$FORCED_COMMAND" >/dev/null 2>&1 || return 1
            if [ -z "$IP_VERSION_FILTER" ]; then
                try_https_with_fallback "$FORCED_COMMAND" "4" && success=1
                try_https_with_fallback "$FORCED_COMMAND" "6" && success=1
            elif [ "$IP_VERSION_FILTER" = "ipv4" ]; then
                try_https_with_fallback "$FORCED_COMMAND" "4" && success=1
            elif [ "$IP_VERSION_FILTER" = "ipv6" ]; then
                try_https_with_fallback "$FORCED_COMMAND" "6" && success=1
            fi
            ;;
        dig|nslookup)
            command -v "$FORCED_COMMAND" >/dev/null 2>&1 || return 1
            if [ -z "$IP_VERSION_FILTER" ]; then
                provider_to_use=$(get_dns_provider "4")
                try_dns_query "$FORCED_COMMAND" "$provider_to_use" "4" && success=1
                provider_to_use=$(get_dns_provider "6")
                try_dns_query "$FORCED_COMMAND" "$provider_to_use" "6" && success=1
            elif [ "$IP_VERSION_FILTER" = "ipv4" ]; then
                provider_to_use=$(get_dns_provider "4")
                try_dns_query "$FORCED_COMMAND" "$provider_to_use" "4" && success=1
            elif [ "$IP_VERSION_FILTER" = "ipv6" ]; then
                provider_to_use=$(get_dns_provider "6")
                try_dns_query "$FORCED_COMMAND" "$provider_to_use" "6" && success=1
            fi
            ;;
        *)
            return 1
            ;;
    esac
    [ $success -eq 1 ] && return 0
    return 1
}

validate_and_output() {
    result="$1"
    [ -z "$result" ] && return 1
    ip_part=$(echo "$result" | cut -d',' -f1)
    ip_version=$(echo "$result" | cut -d',' -f2)
    
    is_valid=0
    if [ "$ip_version" = "4" ]; then
        if echo "$ip_part" | grep -E '^([0-9]{1,3}\.){3}[0-9]{1,3}$' >/dev/null 2>&1; then
            for octet in $(echo "$ip_part" | tr '.' ' '); do
                [ "$octet" -gt 255 ] 2>/dev/null && return 1
            done
            is_valid=1
        fi
    elif [ "$ip_version" = "6" ]; then
        if echo "$ip_part" | grep -E '^[0-9a-fA-F:]+$' >/dev/null 2>&1 && echo "$ip_part" | grep -E ':' >/dev/null 2>&1; then
            colon_count=$(echo "$ip_part" | tr -cd ':' | wc -c)
            if [ "$colon_count" -ge 2 ] && [ "$colon_count" -le 7 ]; then
                is_valid=1
            fi
        fi
    fi
    
    if [ $is_valid -eq 1 ]; then
        if [ $IP_ONLY -eq 1 ]; then
            echo "$ip_part"
        else
            echo "$result"
        fi
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
