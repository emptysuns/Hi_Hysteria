#! /usr/bin/env python3

import urllib.request
from itertools import chain
from datetime import date

domian_white = urllib.request.urlopen(
    'https://raw.githubusercontent.com/emptysuns/daily/gh-pages/chinalist/chinalist.txt'
)
domain_black = urllib.request.urlopen(
    'https://raw.githubusercontent.com/emptysuns/daily/gh-pages/gfwlist/gfwlist.txt'
)
domain_block = urllib.request.urlopen(
    'https://raw.githubusercontent.com/emptysuns/daily/gh-pages/adlist/adlist.txt'
)

cn_ipv4 = urllib.request.urlopen(
    'http://www.ipdeny.com/ipblocks/data/aggregated/cn-aggregated.zone')
cn_ipv6 = urllib.request.urlopen(
    'http://www.ipdeny.com/ipv6/ipaddresses/aggregated/cn-aggregated.zone')
cn = chain(cn_ipv4, cn_ipv6)

with open('routes.acl', 'w') as f:
    f.write('# Author:github.com/emptysuns\n# routes\n# Generated on %s\n\n' %
        date.today().strftime("%B %d, %Y"))
    for block in domain_block:
        block = str(block, 'UTF8').strip()
        if block:
            f.write('block domain-suffix %s\n' % block)
    
    for white in domian_white:
        white = str(white, 'UTF8').strip()
        if white:
            f.write('direct domain-suffix %s\n' % white)
    
    for black in domain_black:
        black = str(black, 'UTF8').strip()
        if black:
            f.write('proxy domain-suffix %s\n' % black)

    for l in cn:
        ls = str(l, 'UTF8').strip()
        if ls:
            f.write('direct cidr %s\n' % ls)
    
    f.write('proxy all')
    f.close()
print('Generate complete!')