## Enable a Masquerade Website

Hysteria2 supports three masquerade modes to disguise your proxy traffic:

### 1. String (default)
Returns a fixed string response. Simple and lightweight.

### 2. Proxy (reverse proxy)
Acts as a reverse proxy, serving content from another website. The remote site's content is relayed through your server.

Configuration: enter the target website URL (e.g., `https://www.example.com`)

### 3. File (static file server)
Serves static files from a local directory. The directory must contain an `index.html` file.

Configuration: specify the local directory path containing your static site.

### Additional Options
- **TCP masquerade:** Also listen on TCP port to enhance the disguise. When a browser visits `https://your-domain:port`, it sees the masquerade content.
- **HTTP/3 blocking:** Optionally block UDP/443 to prevent QUIC connections from bypassing Hysteria2's acceleration. Recommended for better YouTube experience.

### Customization
All masquerade modes support:
- Custom response headers
- Custom status codes
- Custom response body content

