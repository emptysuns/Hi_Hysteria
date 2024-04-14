#! /usr/bin/env python3
import re
import urllib.request
from datetime import date,datetime

start = datetime.now()
print(f'{date.today().strftime("%B %d, %Y")},Loading...\n')
urllib.request.urlretrieve(
    'https://cdn.jsdelivr.net/gh/Loyalsoldier/geoip@release/Country.mmdb', './Country.mmdb'
)

domain_direct = urllib.request.urlopen(
    'https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/direct.txt'
)

domain_ad = urllib.request.urlopen(
    'https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/reject.txt'
)
domain_proxy = urllib.request.urlopen(
    'https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/proxy.txt'
)

a = re.compile(r'([a-z]|[0-9]|[A-Z])(.*[a-z]|[A-Z])')

with open('routes.acl', 'w') as f:
    f.write('# Author:github.com/A1-hub\n# hysteria acl routes\n# Generated on %s\n\n' %
            date.today().strftime("%B %d, %Y"))
    sumc = 0

    count = 0
    for ad in domain_ad:
        rad = str(ad, 'UTF8').strip()
        m = re.search(a, rad).group()
        if m != 'payload':
            count += 1
            f.write('block domain-suffix %s\n' % m)
    print(f'Block rules: {count} done.')
    sumc += count

    count = 0
    for direct in domain_direct:
        rdirect = str(direct, 'UTF8').strip()
        m = re.search(a, rdirect).group()
        if m != 'payload':
            count += 1
            f.write('direct domain-suffix %s\n' % m)
    print(f'Direct rules: {count} done.')
    sumc += count

    count = 0
    for proxy in domain_proxy:
        rproxy = str(proxy, 'UTF8').strip()
        m = re.search(a,rproxy).group()
        if m !='payload' :
            count = count + 1
            f.write('proxy domain-suffix %s\n' % m)
    print(f'Proxy rules: {count} done.')
    sumc += count

    print('\nAll rules:', str(sumc))

    f.write('direct country cn\n')
    f.write('proxy all')
    f.close()
end = datetime.now()
print(f'\nUse: {(end-start).seconds}s\nGenerate completed!')
input('Press any key to exit...')
