#! /usr/bin/env python3

import urllib.request
from datetime import date

domain_black = urllib.request.urlopen(
    'https://raw.githubusercontent.com/emptysuns/daily/gh-pages/gfwlist/gfwlist.txt'
)
domain_block = urllib.request.urlopen(
    'https://raw.githubusercontent.com/emptysuns/daily/gh-pages/adlist/adlist.txt'
)

urllib.request.urlretrieve(
        'https://cdn.jsdelivr.net/gh/Loyalsoldier/geoip@release/Country.mmdb', './Country.mmdb'
)

with open('routes.acl', 'w') as f:
    f.write('# Author:github.com/emptysuns\n# routes\n# Generated on %s\n\n' %
        date.today().strftime("%B %d, %Y"))
    for block in domain_block:
        block = str(block, 'UTF8').strip()
        if block:
            f.write('block domain-suffix %s\n' % block)
    
    for black in domain_black:
        black = str(black, 'UTF8').strip()
        if black:
            f.write('proxy domain-suffix %s\n' % black)


    f.write('direct country cn\n')
    f.write('proxy all')
    f.close()

print('Generate completed!')