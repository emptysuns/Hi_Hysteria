#### Realm Mode (P2P Hole-Punching)

Realm mode allows running a Hysteria2 server without a public IP or port forwarding.

### How It Works
1. Both server and client register with a rendezvous server
2. The rendezvous server helps both sides discover each other's addresses
3. UDP hole-punching establishes a direct connection
4. Traffic flows directly between server and client (not through the rendezvous server)

### Requirements
- Both sides must have UDP connectivity
- STUN servers help discover public NAT addresses
- Works best with full-cone NAT; symmetric NAT may require additional techniques

### Configuration
The script supports both the official rendezvous server (`realm.hy2.io`) and self-hosted rendezvous servers.

**Official rendezvous:** Default token is `public`, no modification needed.

**Rendezvous address format:** `realm://<token>@<rendezvous-host>/<realm-name>`

### Cloudflare WARP Integration
Realm mode can work with Cloudflare WARP to hide the real server IP:
1. Install WARP on the server
2. Hysteria2 uses the WARP IP for Realm hole-punching
3. Clients connect through Cloudflare edge, hiding the real server IP
4. Effectively running Hysteria2 behind Cloudflare CDN

### Client Configuration
- **Native Hysteria2 client:** uses the realm URI directly as the `server` field
- **mihomo:** uses `realm-opts` block (enable/server-url/token/realm-id/stun-servers)
- **sing-box:** uses `realm` block (server_url/token/realm_id/stun_servers), requires 1.14+

### NAT Compatibility
- UPnP/NAT-PMP port mapping is enabled by default
- `ipMode` supports dual/ipv4/ipv6 (default: dual)

