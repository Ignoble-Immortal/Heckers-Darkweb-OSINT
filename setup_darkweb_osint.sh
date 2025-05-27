#!/bin/bash

set -e

echo "Creating darkweb-osint project structure..."

mkdir -p darkweb-osint/core
mkdir -p darkweb-osint/data/logs
mkdir -p darkweb-osint/outputs
mkdir -p darkweb-osint/tools

# config.py
cat > darkweb-osint/config.py << 'EOF'
TOR_PROXY = {
    'http': 'socks5h://127.0.0.1:9050',
    'https': 'socks5h://127.0.0.1:9050'
}

USER_AGENTS = [
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:53.0) Gecko/20100101 Firefox/53.0',
    'Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:53.0) Gecko/20100101 Firefox/53.0',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.11; rv:53.0) Gecko/20100101 Firefox/53.0'
]

KEYWORDS = {'bitcoin', 'hacking', 'market', 'drugs'}
MAX_DEPTH = 2
CRAWL_LIMIT = 50
EOF

# core/utils.py
cat > darkweb-osint/core/utils.py << 'EOF'
import random
from urllib.parse import urlparse, urlunparse
from config import USER_AGENTS

def get_random_user_agent():
    return random.choice(USER_AGENTS)

def is_valid_onion_url(url):
    parsed = urlparse(url)
    if parsed.scheme not in ('http', 'https'):
        return False
    if not parsed.netloc.endswith('.onion'):
        return False
    host = parsed.netloc.split(':')[0]
    prefix = host[:-6]
    return len(prefix) in (16, 56)

def normalize_url(url):
    parsed = urlparse(url)
    scheme = parsed.scheme.lower()
    netloc = parsed.netloc.lower()
    path = parsed.path.rstrip('/')
    normalized = urlunparse((scheme, netloc, path, '', '', ''))
    return normalized
EOF

# core/crawler.py
cat > darkweb-osint/core/crawler.py << 'EOF'
import requests
import time
import random
import logging
from bs4 import BeautifulSoup
from urllib.parse import urljoin
from config import TOR_PROXY, MAX_DEPTH, CRAWL_LIMIT
from core.utils import get_random_user_agent, is_valid_onion_url, normalize_url

logging.basicConfig(level=logging.INFO)
CRAWLED_URLS = set()

def fetch_page(url, retries=3):
    for attempt in range(retries):
        try:
            with requests.Session() as session:
                session.proxies.update(TOR_PROXY)
                session.headers.update({'User-Agent': get_random_user_agent()})
                res = session.get(url, timeout=15)
                if res.status_code == 200:
                    return res.text
                else:
                    logging.warning(f"Non-200 status code {res.status_code} for {url}")
        except requests.exceptions.RequestException as e:
            logging.warning(f"Request error for {url}: {e}")
            time.sleep(2 ** attempt)
    return None

def extract_links(html, base_url):
    soup = BeautifulSoup(html, 'html.parser')
    links = set()
    for tag in soup.find_all('a', href=True):
        abs_url = urljoin(base_url, tag['href'])
        if is_valid_onion_url(abs_url):
            normalized = normalize_url(abs_url.split('?')[0].split('#')[0])
            links.add(normalized)
    return links

def crawl(url, depth, callback):
    normalized_url = normalize_url(url)
    if depth > MAX_DEPTH or len(CRAWLED_URLS) >= CRAWL_LIMIT or normalized_url in CRAWLED_URLS:
        return
    CRAWLED_URLS.add(normalized_url)
    logging.info(f"Crawling {normalized_url} at depth {depth}")
    html = fetch_page(normalized_url)
    if not html:
        logging.warning(f"Failed to fetch {normalized_url}")
        return
    callback(normalized_url, html)
    time.sleep(random.uniform(3, 5))
    for link in extract_links(html, normalized_url):
        if len(CRAWLED_URLS) >= CRAWL_LIMIT:
            break
        crawl(link, depth + 1, callback)
EOF

# core/analyzer.py
cat > darkweb-osint/core/analyzer.py << 'EOF'
import re
from bs4 import BeautifulSoup

def search_keywords(html, keywords):
    found = {}
    content = html.lower()
    for kw in keywords:
        if re.search(r'\b' + re.escape(kw.lower()) + r'\b', content):
            found[kw] = True
    return found

def extract_metadata(html):
    soup = BeautifulSoup(html, 'html.parser')
    title = soup.title.string if soup.title else ''
    metas = {meta.get('name', '').lower(): meta.get('content', '') for meta in soup.find_all('meta') if meta.get('name') and meta.get('content')}
    return {'title': title, 'meta': metas}
EOF

# core/screenshot.py
cat > darkweb-osint/core/screenshot.py << 'EOF'
from selenium import webdriver
from selenium.webdriver.firefox.options import Options
import logging

def capture_screenshot(url, save_path):
    options = Options()
    options.headless = True
    options.set_preference('network.proxy.type', 1)
    options.set_preference('network.proxy.socks', '127.0.0.1')
    options.set_preference('network.proxy.socks_port', 9050)
    options.set_preference("network.proxy.socks_remote_dns", True)

    try:
        driver = webdriver.Firefox(options=options)
    except Exception as e:
        logging.error(f"Failed to start Firefox webdriver: {e}")
        return

    try:
        driver.set_page_load_timeout(30)
        driver.get(url)
        driver.save_screenshot(save_path)
        logging.info(f"Screenshot saved to {save_path}")
    except Exception as e:
        logging.error(f"Screenshot error for {url}: {e}")
    finally:
        driver.quit()
EOF

# core/threat_feed.py
cat > darkweb-osint/core/threat_feed.py << 'EOF'
from urllib.parse import urlparse
import logging

def check_blacklist(url, feed_path="tools/feeds.txt"):
    try:
        parsed = urlparse(url)
        domain = parsed.netloc.lower()
        with open(feed_path, 'r') as f:
            bad_domains = set(line.strip().lower() for line in f if line.strip())
        for bad_domain in bad_domains:
            if domain == bad_domain or domain.endswith('.' + bad_domain):
                logging.info(f"URL {url} is blacklisted due to domain {bad_domain}")
                return True
        return False
    except Exception as e:
        logging.error(f"Error reading blacklist feed: {e}")
        return False
EOF

# main.py
cat > darkweb-osint/main.py << 'EOF'
import os
import sys
import json
import logging
from datetime import datetime
from core import crawler, analyzer, screenshot, threat_feed
from config import KEYWORDS
from core.utils import is_valid_onion_url, normalize_url

os.makedirs("outputs", exist_ok=True)
os.makedirs("data/logs", exist_ok=True)
logging.basicConfig(filename="data/logs/activity.log", level=logging.INFO, format='%(asctime)s %(levelname)s:%(message)s')

results = []

def handle_page(url, html):
    logging.info(f"Analyzing {url}")
    matched = analyzer.search_keywords(html, KEYWORDS)
    meta = analyzer.extract_metadata(html)
    is_malicious = threat_feed.check_blacklist(url)
    screenshot_path = f"outputs/{url.split('//')[-1].replace('/', '_')}.png"
    screenshot.capture_screenshot(url, screenshot_path)

    result = {
        'url': url,
        'keywords_found': list(matched.keys()),
        'metadata': meta,
        'blacklisted': is_malicious,
        'screenshot': screenshot_path,
        'timestamp': datetime.utcnow().isoformat()
    }
    results.append(result)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python main.py <start_onion_url>")
        sys.exit(1)

    start_url = sys.argv[1]
    if not is_valid_onion_url(start_url):
        print("[!] Invalid .onion URL.")
        sys.exit(1)

    normalized_start_url = normalize_url(start_url)
    crawler.crawl(normalized_start_url, 0, handle_page)

    with open('outputs/results.json', 'w') as f:
        for entry in results:
            f.write(json.dumps(entry) + '\n')

    print("[✓] Crawling completed.")
    logging.info("Crawling completed.")
EOF

# requirements.txt
cat > darkweb-osint/requirements.txt << 'EOF'
requests
beautifulsoup4
selenium
stem
lxml
EOF

# tools/feeds.txt
cat > darkweb-osint/tools/feeds.txt << 'EOF'
# Add known blacklisted onion domains here, one per line
badmarket.onion
malicioussite.onion
EOF

echo "Setup complete! Navigate to the 'darkweb-osint' directory and run:"
echo "  python3 -m venv venv"
echo "  source venv/bin/activate"
echo "  pip install -r requirements.txt"
echo "Then run the crawler with:"
echo "  python main.py http://exampleonionaddress.onion"
echo "Replace the example URL with a valid .onion address."

exit 0
