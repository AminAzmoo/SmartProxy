#!/usr/bin/env python3

import json
import sys
import time
from urllib.request import urlopen, Request
from urllib.error import URLError

PROXY_SOURCES = [
    {'name': 'Free Proxy List', 'url': 'https://www.proxy-list.download/api/v1/get?type=http', 'parse': 'json_data'},
    {'name': 'ProxyScrape', 'url': 'https://api.proxyscrape.com/v2/?request=getproxies&protocol=http&timeout=5000&ssl=all&anonymity=all&country=all&format=json', 'parse': 'json_proxyscrape'},
    {'name': 'GeoNode', 'url': 'https://proxylist.geonode.com/api/proxy-list?limit=500&page=1&sort_by=lastChecked&sort_type=desc', 'parse': 'json_geonode'},
]

def fetch_from_source(source):
    proxies = []
    try:
        headers = {'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36'}
        req = Request(source['url'], headers=headers)
        response = urlopen(req, timeout=10)
        data = response.read().decode('utf-8')
        
        if source['parse'] == 'json_data':
            json_data = json.loads(data)
            if 'RESULT' in json_data:
                for item in json_data['RESULT']:
                    ip = item.get('IP')
                    port = item.get('PORT')
                    if ip and port:
                        proxies.append({'proxy': f"{ip}:{port}", 'country': item.get('Country', 'Unknown'), 'source': source['name']})
        
        elif source['parse'] == 'json_proxyscrape':
            json_data = json.loads(data)
            if 'proxies' in json_data:
                for item in json_data['proxies']:
                    if ':' in item.get('proxy', ''):
                        proxies.append({'proxy': item['proxy'], 'country': item.get('country', 'Unknown'), 'source': source['name']})
        
        elif source['parse'] == 'json_geonode':
            json_data = json.loads(data)
            if 'data' in json_data:
                for item in json_data['data']:
                    ip = item.get('ip')
                    port = item.get('port')
                    if ip and port:
                        proxies.append({'proxy': f"{ip}:{port}", 'country': item.get('country', {}).get('isoCode', 'Unknown'), 'source': source['name']})
    
    except Exception as e:
        print(f"Error fetching from {source['name']}: {str(e)}", file=sys.stderr)
    
    return proxies

def main():
    try:
        all_proxies = []
        for source in PROXY_SOURCES:
            proxies = fetch_from_source(source)
            all_proxies.extend(proxies)
            time.sleep(0.5)
        
        unique = {}
        for p in all_proxies:
            if p['proxy'] not in unique:
                unique[p['proxy']] = p
        
        print(json.dumps(list(unique.values())[:50], ensure_ascii=False, indent=2))
    
    except Exception as e:
        print(json.dumps([], ensure_ascii=False))
        sys.exit(1)

if __name__ == '__main__':
    main()
