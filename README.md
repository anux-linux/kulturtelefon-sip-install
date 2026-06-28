# Install Scripts for kulturtelefon stack

Provisions a FreeSWITCH-based SIP server on a fresh Debian host, together with
the firewalling, intrusion-prevention and tooling needed to expose it safely on
the public internet.

## Components

The installer sets up the following components:

- **FreeSWITCH** (from the SignalWire Debian repository) with a curated set of
  modules: `mod_sofia`, `mod_dialplan-xml`, `mod_event-socket`, `mod_xml-curl`,
  `mod_http-cache`, `mod_conference`, `mod_callcenter`, `mod_verto`,
  `mod_lua`, codec/sound packs, CDR backends, etc. See
  [src/resources/switch/package-all.sh](src/resources/switch/package-all.sh)
  for the full module list.
- **Custom SIP profiles** for the `internal` and `external` Sofia profiles,
  with IPv6 profiles disabled, NAT/public-IP settings applied, and an
  auto-generated Event Socket password.
- **iptables firewall** with SIP scanner signature drops, RTP/SIP port
  allowances and DSCP QoS marking, made persistent via
  `iptables-persistent`.
- **Fail2ban** with custom FreeSWITCH filters and jails for SIP auth failures,
  ACL violations and authentication challenges.
- **sngrep** for live SIP traffic inspection.
- **SNMP** (`snmpd`) with a read-only `public` community for monitoring.
- **Build toolchain & utilities**: `build-essential`, `autoconf`, `libtool`,
  `pkg-config`, `libssl-dev`, `libcurl4-openssl-dev`, `git`, `curl`, `wget`,
  `nano`, `net-tools`, `gpg`, `dialog`, `ntp`, `haveged`, `memcached`, `sox`.

## Project structure

```
src/
├── pre-install.sh                   # Bootstrap: clones repo into /usr/src
├── install.sh                       # Top-level installer (entry point)
└── resources/
    ├── config.sh                    # Reads required env vars (SWITCH_TOKEN)
    ├── colors.sh                    # verbose/error logging helpers
    ├── iptables.sh                  # Firewall rules + iptables-persistent
    ├── fail2ban.sh                  # Installs fail2ban + filters/jails
    ├── sngrep.sh                    # Installs sngrep
    ├── switch.sh                    # Orchestrates the FreeSWITCH install
    ├── fail2ban/                    # Filter and jail definitions
    │   ├── jail.local
    │   ├── fail2ban.local
    │   ├── freeswitch.conf
    │   ├── freeswitch-acl.conf
    │   ├── freeswitch-ip.conf
    │   ├── sip-auth-failure.conf
    │   ├── sip-auth-challenge.conf
    │   └── auth-challenge-ip.conf
    ├── monit/
    │   └── freeswitch               # Monit watch config for FreeSWITCH
    └── switch/
        ├── package-all.sh           # Adds SignalWire repo + apt installs
        ├── configure-sip.sh         # Deploys SIP profiles + ESL + http_cache
        ├── sip_profiles/
        │   ├── internal.xml         # Internal profile (template)
        │   └── external.xml         # External profile (template)
        └── config/
            ├── event_socket.conf.xml
            └── http_cache.conf.xml
```

## Variables to set

The installer reads two variables:

| Variable                | Required | Source                          | Purpose                                                                                                 |
| ----------------------- | -------- | ------------------------------- | ------------------------------------------------------------------------------------------------------- |
| `SWITCH_TOKEN`          | Yes      | environment, before `install.sh`| SignalWire personal access token, used as the apt password for `freeswitch.signalwire.com`.             |
| `freeswitch_public_ip`  | No       | environment, before `install.sh`| Public IP injected into the SIP profile templates. Auto-detected via `ifconfig.me` / `icanhazip.com` / `ipinfo.io` if unset. |

`SWITCH_TOKEN` is consumed by [src/resources/config.sh](src/resources/config.sh)
and the script aborts if it is missing.

## Install procedure

Run as `root` on a fresh Debian host.

1. **Bootstrap** (clones this repo into `/usr/src/kulturtelefon-sip-install`):

   ```sh
   wget -O - https://raw.githubusercontent.com/anux-linux/kulturtelefon-sip-install/main/src/pre-install.sh | sh
   ```

   Or clone manually:

   ```sh
   cd /usr/src && git clone https://github.com/anux-linux/kulturtelefon-sip-install.git
   ```

2. **Export the SignalWire token** (and optionally pin the public IP):

   ```sh
   export SWITCH_TOKEN="your-signalwire-personal-access-token"
   export freeswitch_public_ip="203.0.113.10"   # optional
   ```

3. **Run the installer**:

   ```sh
   cd /usr/src/kulturtelefon-sip-install/src
   sh install.sh
   ```

The installer runs in this order: apt upgrade → base packages → SNMP →
iptables → sngrep → fail2ban → FreeSWITCH (packages + SIP/ESL/http_cache
configuration) → enable and restart `freeswitch.service`.

## Required runtime configuration

After the installer finishes, the following items are written to the host and
should be reviewed or rotated as needed:

- **SIP profiles** — [/etc/freeswitch/sip_profiles/internal.xml](src/resources/switch/sip_profiles/internal.xml)
  and `external.xml`. The placeholder `FREESWITCH_PUBLIC_IP_PLACEHOLDER` is
  replaced with `$freeswitch_public_ip`. Original profiles are backed up to
  `*.xml.orig`; the IPv6 profiles are renamed to `*.disabled`.
- **Event Socket** — `/etc/freeswitch/autoload_configs/event_socket.conf.xml`
  bound to `localhost:8021`. A random 12-character password is generated and
  written to `src/.event_socket_password` (mode `600`). Rotate by editing the
  XML and restarting FreeSWITCH.
- **HTTP cache** — `/etc/freeswitch/autoload_configs/http_cache.conf.xml`
  with cache directory `/var/cache/freeswitch/http_cache` (owner
  `freeswitch:freeswitch`, mode `750`). `mod_http_cache` is added to
  `modules.conf.xml` if not already present.
- **Firewall** — rules in `/etc/iptables/rules.v4` (saved by
  `iptables-persistent`). Open ports: `22/tcp` (SSH), `5060–5091/tcp+udp`
  (SIP), `16384–32768/udp` (RTP), `1194/udp` (OpenVPN), ICMP echo. HTTP/HTTPS
  are commented out by default — uncomment in
  [src/resources/iptables.sh](src/resources/iptables.sh) if a web stack is
  needed.
- **Fail2ban** — filters in `/etc/fail2ban/filter.d/` and jails in
  `/etc/fail2ban/jail.local`. Adjust ban times / ignore IPs there.
- **SNMP** — `/etc/snmp/snmpd.conf` ships with `rocommunity public`. Replace
  with a private community string and bind address before exposing the host.
- **SignalWire credentials** — `/etc/apt/auth.conf` holds the SignalWire
  token in plaintext (mode should be `600`); needed for future
  `apt-get upgrade` runs of FreeSWITCH packages.
- **FreeSWITCH service** — managed by systemd: `systemctl status freeswitch`,
  logs via `journalctl -u freeswitch`.
