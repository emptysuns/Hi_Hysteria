#### Self-Signed Certificates

The script provides four certificate methods:

1. **ACME HTTP Challenge** (recommended) — requires TCP port 80 to be open
2. **Local Certificate Files** — use your own cert and key files
3. **Self-Signed Certificate** (default) — generates a certificate for any domain, verified via pinSHA256 fingerprint (secure, no domain/port needed)
4. **ACME DNS Challenge** — for DNS-based validation

**Self-signed certificate security:** Starting from ver1.12, self-signed certificates use pinSHA256 fingerprint verification by default. Clients verify the server's certificate fingerprint rather than relying on CA trust chains. This is both secure and convenient — no need for a real domain or open ports.

**Client configuration:**
- Native Hysteria2 client: uses `tls.pinSHA256` field
- mihomo client: uses `fingerprint` field
- sing-box client: embeds CA certificate via `tls.certificate` field

