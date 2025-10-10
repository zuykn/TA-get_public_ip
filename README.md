# Get Public IP Add-on by zuykn.io

Collects the external public IPv4 and IPv6 addresses in use by a Splunk Universal Forwarder/Enterprise for Windows, Linux, Unix, and macOS.

## Features

### Platform
- Cross‑platform support: Windows, Linux, Unix, macOS.
- For Universal Forwarders, standalone, or distributed deployments.
- Automatic command selection based on built-in tools.
- Two acquisition methods: HTTPS endpoint query or DNS resolver lookup.
- Intelligent fallback ordering that adapts to chosen mode and success/failure.
- **Dual-stack support**: IPv4 and IPv6 address collection.

### Customization
- HTTPS: supply any host/path that returns an IP address (e.g. `ipv4.icanhazip.com` (default), `ipv6.icanhazip.com`, `ipinfo.io/ip`, `api.ipify.org`, `4.ident.me`)
- DNS preconfigured providers: `opendns` (default), `cloudflare`
- Mode control flags: `-https-only` or `-dns-only`
- IP version filtering: `-ipv4-only` or `-ipv6-only`
- Version-specific endpoints: `-https-4`, `-https-6`, `-dns-4`, `-dns-6`
- Output control: `-ip-only` for minimal output
- Force a specific tool with `-command <command>`
  - Windows tools: `curl | certutil | bitsadmin | nslookup`
  - Linux/Unix/macOS tools: `curl | wget | dig | nslookup`
- Adjustable timeout: `-timeout <seconds>`

### Security
- Uses built-in tools; no external tools or libraries required.
- HTTPS retrieval uses TLS.
- DNS uses trusted public resolvers (OpenDNS, Cloudflare).
- Low likelihood of triggering EDR.

### Performance
- Quick execution; negligible CPU/memory usage.
- Single-line output per run for low parsing overhead.

## Installation

1. **Download** the add-on package to your search head (for search-time extractions) and Universal Forwarder (for inputs).
2. **Extract** to your Splunk apps directory:
   - **Universal Forwarder or Splunk Enterprise**: `$SPLUNK_HOME/etc/apps/`
3. **Configure** index, collection interval (default: 300 seconds), and script parameters (see Usage section below).
4. **Enable** the scripted input in `inputs.conf` by setting `disabled = 0`.
5. **Restart** the Splunk Universal Forwarder to enable `inputs.conf` (search head doesn't require restart for search-time field extractions).

## Usage

Both scripts share a consistent CLI:

### Windows (get_public_ip.bat)

```text
Usage: .\get_public_ip.bat [-timeout <seconds>] [-https <host[/path]>] [-https-4 <host[/path]>] [-https-6 <host[/path]>] [-dns <provider>] [-dns-4 <provider>] [-dns-6 <provider>] [-https-only] [-dns-only] [-ipv4-only] [-ipv6-only] [-ip-only] [-command <command>]

Providers (for -dns, -dns-4, -dns-6):
  opendns | cloudflare
Commands (for -command):
  curl | certutil | bitsadmin | nslookup
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
  If -command is set it must not conflict with a chosen mode (e.g. forcing nslookup with -https-only).
  Version-specific parameters (-https-4, -https-6, -dns-4, -dns-6) override general parameters for their respective IP versions.
Examples:
  [script://.\bin\get_public_ip.bat -timeout 5]
  [script://.\bin\get_public_ip.bat -https ipinfo.io/ip]
  [script://.\bin\get_public_ip.bat -https-4 ipv4.icanhazip.com -https-6 ipv6.icanhazip.com]
  [script://.\bin\get_public_ip.bat -dns cloudflare]
  [script://.\bin\get_public_ip.bat -dns-4 cloudflare -dns-6 opendns]
  [script://.\bin\get_public_ip.bat -dns-only -dns cloudflare]
  [script://.\bin\get_public_ip.bat -https-only -https ipv4.icanhazip.com]
  [script://.\bin\get_public_ip.bat -ipv4-only -ip-only]
  [script://.\bin\get_public_ip.bat -ipv6-only]
  [script://.\bin\get_public_ip.bat -command curl]
  [script://.\bin\get_public_ip.bat -command nslookup]
  # Automatically detects the best method and command, using default endpoints or resolvers.
  [script://.\bin\get_public_ip.bat]
  index = main
  sourcetype = public_ip
  interval = 300
  disabled = 0
```

### Linux/Unix/macOS (get_public_ip.sh)

```text
Usage: ./get_public_ip.sh [-timeout <seconds>] [-https <host[/path]>] [-https-4 <host[/path]>] [-https-6 <host[/path]>] [-dns <provider>] [-dns-4 <provider>] [-dns-6 <provider>] [-https-only] [-dns-only] [-ipv4-only] [-ipv6-only] [-ip-only] [-command <command>]

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
  [script://./bin/get_public_ip.sh -timeout 5]
  [script://./bin/get_public_ip.sh -https ipinfo.io/ip]
  [script://./bin/get_public_ip.sh -https-4 ipv4.icanhazip.com -https-6 ipv6.icanhazip.com]
  [script://./bin/get_public_ip.sh -dns cloudflare]
  [script://./bin/get_public_ip.sh -dns-4 cloudflare -dns-6 opendns]
  [script://./bin/get_public_ip.sh -dns-only -dns cloudflare]
  [script://./bin/get_public_ip.sh -https-only -https ipv4.icanhazip.com]
  [script://./bin/get_public_ip.sh -ipv4-only -ip-only]
  [script://./bin/get_public_ip.sh -ipv6-only]
  [script://./bin/get_public_ip.sh -command curl]
  [script://./bin/get_public_ip.sh -command nslookup]
  # Automatically detects the best method and command, using default endpoints or resolvers.
  [script://./bin/get_public_ip.sh]
  index = main
  sourcetype = public_ip
  interval = 300
  disabled = 0
```

### Fields

The add-on extracts the following fields from the collected data for sourcetype `public_ip`:

| Field | Description | Example Values |
|-------|-------------|----------------|
| `public_ip` | The external public IP address | `203.0.113.45`, `2001:db8::1` |
| `ip_version` | IP protocol version | `4`, `6` |
| `method` | Acquisition method used | `https`, `dns` |
| `provider` | Service provider or endpoint used | `ipv4.icanhazip.com`, `ipv6.icanhazip.com`, `opendns`, `cloudflare` |
| `command` | System command/tool that retrieved the IP | `curl`, `wget`, `dig`, `nslookup`, `certutil`, `bitsadmin` |
| `source` | Splunk source field | Script path and parameters |
| `host` | Splunk host field | Hostname where script executed |

### Data Output Format

The scripts output a single line of CSV data per execution:

```
52.5.196.118,4,https,ipv4.icanhazip.com,curl
2001:db8::1,6,https,ipv6.icanhazip.com,curl
52.1.114.19,4,dns,opendns,dig
2001:db8::2,6,dns,cloudflare,nslookup
```

Format: `public_ip,ip_version,method,provider,command`

### Sample SPL

#### View Latest Public IP by Host
This search retrieves the latest public IP information for each host in your environment and displays it in a table format.

```spl
index=main sourcetype=public_ip 
| stats latest(public_ip) as public_ip
    latest(ip_version) as ip_version
    latest(method) as method
    latest(provider) as provider
    latest(command) as command
    by host 
| table host public_ip ip_version method provider command
```

#### View IPv4 and IPv6 Addresses by Host
This search shows both IPv4 and IPv6 addresses for each host, displaying them in separate columns.

```spl
index=main sourcetype=public_ip 
| eval ip_type=if(ip_version="4","ipv4","ipv6")
| stats latest(public_ip) as public_ip by host ip_type
| eval {ip_type}=public_ip
| stats values(ipv4) as ipv4 values(ipv6) as ipv6 by host
| table host ipv4 ipv6
```

#### Geographic Distribution of Public IPs

This search retrieves the geographic distribution of public IPs by city. Use with the Cluster Map Visualization to plot the data on a map.

```spl
index=main sourcetype=public_ip 
| stats latest(public_ip) as public_ip
    latest(ip_version) as ip_version
    latest(method) as method
    latest(provider) as provider
    latest(command) as command
    by host
| iplocation public_ip
| geostats count by City
```

## Support

Need help, want a custom version, or have a feature request? Contact us—​we're happy to help!
- **Website**: https://zuykn.io
- **Docs**: https://docs.zuykn.io
- **Email**: support@zuykn.io

## License
Licensed under the Apache License, Version 2.0

---
© 2023-2025 zuykn. All Rights Reserved.
