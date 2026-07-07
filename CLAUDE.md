# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Hi Hysteria** is a comprehensive installation and management framework for Hysteria2, a high-performance network tool optimized for congested and high-latency networks. The project provides:

- Automated installation and configuration via interactive shell scripts
- Server management (start, stop, restart, status monitoring)
- Core binary updates and version management
- Advanced features: Realm mode (P2P hole-punching), Cloudflare WARP integration, obfuscation, certificate management
- ACL-based domain filtering and traffic statistics monitoring
- Multi-OS/architecture support (x86_64, ARM, Alpine, Debian, etc.)

## Common Development Tasks

### Testing
```bash
# Test the bootstrap installer
bash ./server/test_bootstrap_install.sh

# Test install recovery and system state management
bash ./server/test_install_recovery.sh
```

### Running the Main Script
```bash
# Run the main installer locally (useful for testing changes)
bash ./server/hy2.sh

# For actual deployment, users run:
bash <(curl -fsSL https://git.io/hysteria.sh)
```

### Linting
The project uses bash with strict settings (`set -euo pipefail`). For code review:
```bash
# Check shell syntax (install shellcheck first if needed)
shellcheck server/hy2.sh server/install.sh server/test_*.sh
```

## Architecture & Key Components

### Entry Points

1. **`server/install.sh`** (bootstrap, 84 lines)
   - Downloads and installs the main `hy2.sh` script
   - Allows users to choose between Hysteria2 (default, recommended) or Hysteria1
   - Handles environment setup and error handling with clean fallback when wget/curl unavailable

2. **`server/hy2.sh`** (main script, 3859 lines)
   - Interactive menu-driven CLI for server management
   - Divided into logical sections by function:
     - **Installation**: Certificate setup, Hysteria2 core installation, configuration generation
     - **Server Management**: Start/stop/restart, status monitoring, log viewing
     - **Updates**: Core binary updates, script self-updates, version checking
     - **Configuration**: Port hopping, ACL/domain filtering, WARP setup, Realm mode
     - **Statistics**: Real-time traffic monitoring, user statistics
     - **Utilities**: Download helpers, validation, format functions

### Core Functions (Key Patterns)

**Download & Networking**:
- `downloadToFile()` — downloads files using wget/curl with fallbacks
- `fetchRemoteBodyFromSources()` / `fetchRemoteHeadersFromSources()` — fetch from multiple mirrors (GitHub + jsdelivr CDN)
- `getLatestHysteriaVersion()` / `getLatestHihyVersion()` — version detection from GitHub releases

**Configuration & Validation**:
- `startInstallValidationProcess()` — tests generated config by running Hysteria2 in validation mode
- Configuration is YAML-based, managed by `yq` binary
- Config stored in `/etc/hihy/` with result files (certificates, config, client configs)

**User Interaction**:
- `echoColor()` — colored output (red, green, purple, orange)
- Menu-driven interface supporting numeric shortcuts (`hihy 5` = restart, `hihy 1` = install, etc.)

**Realm Mode** (P2P hole-punching):
- Uses rendezvous servers for NAT traversal
- Integrates with Cloudflare WARP for IP masking
- Default rendezvous: `realm.hy2.io` with public authentication

### File Structure

```
/etc/hihy/                       # Main config directory
├── config.yaml                  # Server config
├── ca.crt / server.crt / server.key  # SSL certificates
└── result/
    ├── client configs           # Generated client configs (v2rayN, etc.)
    ├── version-check.state      # Cached version info with TTL
    └── version-check.lock       # Prevents concurrent version checks

/usr/bin/hihy                    # Symbolic link to hy2.sh (launcher)
/var/run/hihy.pid               # Process ID file
```

## Common Code Patterns

### Error Handling & Validation

All scripts use `set -euo pipefail`:
- `-e` — exit on first error
- `-u` — error on undefined variables  
- `-o pipefail` — propagate pipe failures

Note: the main `hy2.sh` script does NOT use `set -euo pipefail` (install.sh, test scripts, and build scripts do). This is deliberate — the interactive menu must not exit on user input errors.

Example:
```bash
if ! downloadToFile "$url" "$output"; then
    echoColor red "Download failed"
    return 1
fi
```

### Testing Assertions

Custom assertion functions (from `test_bootstrap_install.sh`):
- `assert_equals expected actual message` — equality check
- `assert_file_contains path expected_text message` — substring check
- `assert_executable path message` — executable permission check

### Configuration Generation

YAML-based config uses `yq` for manipulation:
- All keys validated during installation
- Config tested by spawning Hysteria2 in validation mode
- Client configs generated from server config (preserved parameters for v2rayN, Nekoray, etc.)

### Version Management

- Version stored in script header as variable: `hihyV="ver1.12"`
- Remote version detection uses GitHub releases API (with fallback to mirror)
- TTL-based version check cache (`HIHY_VERSION_CHECK_TTL=21600` = 6 hours) prevents excessive network calls
- Version state file tracks last check timestamp to prevent notification spam

## Build System & Architecture

- `server/hy2.sh` is a **generated artifact** from `server/src/*.sh` modules (sorted by numeric prefix) — edit in `src/`, run `bash scripts/build.sh`, never hand-edit the artifact
- `server/test_build.sh` verifies artifact/source sync (fails if someone forgot to rebuild)
- i18n: `server/i18n/{en,zh,fa,ru}.json` (470+ keys each); `scripts/i18n-validate.sh` checks key consistency + printf placeholder counts
- Client config generators share `loadClientParams()` from `70-client-common.sh`:
  - `72-client-native.sh` — native Hysteria2 YAML + hy2:// share link
  - `74-client-mihomo.sh` — mihomo (ex-ClashMeta) YAML
  - `76-client-singbox.sh` — sing-box JSON (baseline 1.11+)

## Development Workflow Tips

### When Adding Features

1. **Large features** (e.g., new certificate method, new obfuscation type): Add new menu option and corresponding handler function
2. **Configuration options**: Update YAML generation, validation, and client config export
3. **Remote operations** (downloads, version checks): Use `fetchRemoteBodyFromSources()` with mirror fallback
4. **User prompts**: Use `echoColor` for consistency; support both manual input and numeric shortcuts

### When Debugging

- Main logs: `/var/log/hihy/` (Hysteria2 output)
- Debug output from config validation: `./hihy_debug.info`
- PID file location: `/var/run/hihy.pid`
- Use `hihy 14` (view logs) or check systemd journal for running processes

### When Testing Changes

- Run `test_bootstrap_install.sh` to verify installation flow
- Run `test_install_recovery.sh` to verify system state management (process cleanup, config preservation)
- Manual test: `bash ./server/hy2.sh` to exercise the interactive menu
- Check shellcheck for syntax issues

## Important Constraints & Patterns

### Platform Support

The script supports multiple Linux distributions and virtualization types. When adding features:
- Test detection works for: Alpine, Arch, Debian, Ubuntu, CentOS, RHEL, Rocky Linux, AlamaLinux
- Account for architecture differences: x86_64, i386, aarch64, armv7, s390x, ppc64le
- Be aware of LXC/OpenVZ memory constraints (cannot modify `net.core.rmem_max`)

### Network Resilience

- **Multiple download mirrors**: GitHub + jsdelivr CDN fallback for robustness
- **Timeout handling**: `HIHY_REMOTE_CONNECT_TIMEOUT=2`, `HIHY_REMOTE_MAX_TIME=5` — fail fast
- **Version check caching**: TTL prevents hammering GitHub API; lock file prevents concurrent checks

### Security Considerations

- Realm mode credentials (rendezvous URL) should not be logged or exposed
- User authentication password generation (UUID by default)
- SSL certificate validation (pinSHA256 fingerprints for self-signed certs)
- WARP integration hides real server IP (applies to Realm mode connections only)

## Recent Changes & Commit Patterns

The project is actively maintained. Recent work (ver1.11 → ver1.12) focuses on:
- Script modularization (hy2.sh split into server/src/ modules, assembled by build.sh)
- i18n multi-language support (en/zh/fa/ru, pure-bash JSON loader, merge from `feature/i18n-support`)
- ClashMeta renamed to mihomo; congestion/gecko/bbr-profile/hop-interval/realm-opts fixes
- New sing-box client config generator (baseline 1.11+, realm/gecko/bbr_profile 1.14+)
- Unified ruleset mirror via jsDelivr (HIHY_RULESET_MIRROR, replaces hardcoded ghgo.xyz)

Commit style: `type: short description — longer detail` (e.g., `fix: improve uninstall cleanup - kill processes and remove Hysteria2 iptables chains`)

## Reference Documentation

- **User Guides**: `/md/` directory
  - `firewall.md` — firewall configuration
  - `realm.md` — P2P Realm mode setup
  - `certificate.md` — certificate options
  - `client.md` — supported clients
  - `speed.md` — bandwidth configuration
  - `masquerade.md` — website masquerading
  - `blacklist.md` — ISP limitations by provider
  - `issues.md` — troubleshooting
