#### حالت Realm (سوراخ‌کردن P2P)

حالت Realm امکان اجرای سرور Hysteria2 بدون IP عمومی یا ارسال پورت را فراهم می‌کند.

### نحوه عملکرد
۱. هم سرور و هم کلاینت در سرور rendezvous ثبت‌نام می‌کنند
۲. سرور rendezvous به هر دو طرف کمک می‌کند آدرس‌های یکدیگر را کشف کنند
۳. سوراخ‌کردن UDP یک اتصال مستقیم برقرار می‌کند
۴. ترافیک مستقیماً بین سرور و کلاینت جریان می‌یابد (نه از طریق سرور rendezvous)

### نیازمندی‌ها
- هر دو طرف باید اتصال UDP داشته باشند
- سرورهای STUN به کشف آدرس‌های NAT عمومی کمک می‌کنند
- با NAT full-cone بهترین کار را می‌کند؛ NAT متقارن ممکن است به تکنیک‌های اضافی نیاز داشته باشد

### پیکربندی
اسکریپت هم از سرور rendezvous رسمی (`realm.hy2.io`) و هم از سرورهای rendezvous شخصی پشتیبانی می‌کند.

**Rendezvous رسمی:** توکن پیش‌فرض `public` است، نیازی به تغییر نیست.

**فرمت آدرس Rendezvous:** `realm://<token>@<rendezvous-host>/<realm-name>`

### یکپارچگی Cloudflare WARP
حالت Realm می‌تواند با Cloudflare WARP برای مخفی‌سازی IP واقعی سرور کار کند:
۱. WARP را روی سرور نصب کنید
۲. Hysteria2 از IP WARP برای سوراخ‌کردن Realm استفاده می‌کند
۳. کلاینت‌ها از طریق لبه Cloudflare متصل می‌شوند و IP واقعی سرور را مخفی می‌کنند
۴. عملاً Hysteria2 را پشت CDN Cloudflare اجرا می‌کند

### پیکربندی کلاینت
- **کلاینت اصلی Hysteria2:** از URI realm مستقیماً به عنوان فیلد server استفاده می‌کند
- **mihomo:** از بلوک realm-opts استفاده می‌کند (enable/server-url/token/realm-id/stun-servers)
- **sing-box:** از بلوک realm استفاده می‌کند (server_url/token/realm_id/stun_servers)، نیاز به 1.14+

### سازگاری NAT
- نگاشت پورت UPnP/NAT-PMP به طور پیش‌فرض فعال است
- ipMode از dual/ipv4/ipv6 پشتیبانی می‌کند (پیش‌فرض: dual)

