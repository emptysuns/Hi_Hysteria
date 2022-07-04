#! /usr/bin/env python3
import re
import urllib.request
from datetime import date

urllib.request.urlretrieve(
    'https://cdn.jsdelivr.net/gh/Loyalsoldier/geoip@release/Country.mmdb', './Country.mmdb'
)
domain_ad = urllib.request.urlopen(
    'https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/reject.txt'
)
domain_proxy = urllib.request.urlopen(
    'https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/proxy.txt'
)

a = re.compile(r'([a-z]|[0-9])(.*[a-z])')

with open('routes.acl', 'w') as f:
    f.write('# Author:github.com/A1-hub\n#hysteria acl routes\n# Generated on %s\n\n' %
            date.today().strftime("%B %d, %Y"))
    for proxy in domain_proxy:
        rproxy = str(proxy, 'UTF8').strip()
        m = re.search(a,rproxy).group()
        if m !='payload' :
            f.write('proxy domain-suffix %s\n' % m)

    for ad in domain_ad:
        rad = str(ad, 'UTF8').strip()
        m = re.search(a,rad).group()
        if m != 'payload':
            f.write('block domain-suffix %s\n' % m)

    f.write('direct country cn\n')
    f.write('proxy all')
    f.close()

print('Generate completed!')