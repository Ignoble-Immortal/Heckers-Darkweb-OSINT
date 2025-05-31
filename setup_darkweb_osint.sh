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

KEYWORDS = {'bitcoin', 'hacking', 'market', 'drugs','carding','fraud','scam','hack','wiki','forum'}
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
import logging
import time
import random
from selenium import webdriver
from selenium.webdriver.firefox.options import Options
from selenium.common.exceptions import TimeoutException, WebDriverException
from urllib.parse import urljoin
from config import MAX_DEPTH, CRAWL_LIMIT, USER_AGENTS
from core.utils import get_random_user_agent, is_valid_onion_url, normalize_url

CRAWLED_URLS = set()

class TorCrawler:
    def __init__(self):
        self.options = Options()
        self.options.headless = True
        self.options.set_preference('network.proxy.type', 1)
        self.options.set_preference('network.proxy.socks', '127.0.0.1')
        self.options.set_preference('network.proxy.socks_port', 9050)
        self.options.set_preference("network.proxy.socks_remote_dns", True)
        self.options.set_preference("dom.webdriver.enabled", False)
        self.options.set_preference('useAutomationExtension', False)

        # Set random user agent
        user_agent = random.choice(USER_AGENTS)
        self.options.set_preference("general.useragent.override", user_agent)

        try:
            self.driver = webdriver.Firefox(options=self.options)
            self.driver.set_page_load_timeout(30)
        except Exception as e:
            logging.error(f"Failed to start Firefox webdriver: {e}")
            self.driver = None

    def fetch_page(self, url, retries=3):
        if not self.driver:
            logging.error("Webdriver not initialized.")
            return None

        for attempt in range(retries):
            try:
                self.driver.get(url)
                time.sleep(5)  # wait for JS to load
                html = self.driver.page_source
                return html
            except (TimeoutException, WebDriverException) as e:
                logging.warning(f"Selenium error on {url}: {e}")
                time.sleep(2 ** attempt)
        return None

    def capture_screenshot(self, url, save_path):
        if not self.driver:
            logging.error("Webdriver not initialized for screenshot.")
            return False
        try:
            self.driver.get(url)
            time.sleep(5)  # wait for page to load
            self.driver.save_screenshot(save_path)
            logging.info(f"Screenshot saved to {save_path}")
            return True
        except Exception as e:
            logging.error(f"Screenshot error for {url}: {e}")
            return False

    def extract_links(self, html, base_url):
        from bs4 import BeautifulSoup
        soup = BeautifulSoup(html, 'html.parser')
        links = set()
        for tag in soup.find_all('a', href=True):
            abs_url = urljoin(base_url, tag['href'])
            if is_valid_onion_url(abs_url):
                normalized = normalize_url(abs_url.split('?')[0].split('#')[0])
                links.add(normalized)
        return links

    def crawl(self, url, depth, callback):
        normalized_url = normalize_url(url)
        if depth > MAX_DEPTH or len(CRAWLED_URLS) >= CRAWL_LIMIT or normalized_url in CRAWLED_URLS:
            return
        CRAWLED_URLS.add(normalized_url)
        logging.info(f"Crawling {normalized_url} at depth {depth}")
        html = self.fetch_page(normalized_url)
        if not html:
            logging.warning(f"Failed to fetch {normalized_url}")
            return
        callback(normalized_url, html)
        time.sleep(3)  # polite delay
        for link in self.extract_links(html, normalized_url):
            if len(CRAWLED_URLS) >= CRAWL_LIMIT:
                break
            self.crawl(link, depth + 1, callback)

    def close(self):
        if self.driver:
            self.driver.quit()
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
import threading
import time
from datetime import datetime
from flask import Flask, render_template_string, send_from_directory
from core import analyzer, threat_feed
from core.utils import is_valid_onion_url, normalize_url
from core.crawler import TorCrawler
from config import KEYWORDS

os.makedirs("outputs", exist_ok=True)
os.makedirs("data/logs", exist_ok=True)
logging.basicConfig(filename="data/logs/activity.log", level=logging.INFO, format='%(asctime)s %(levelname)s:%(message)s')

RESULTS_FILE = 'outputs/results.json'

app = Flask(__name__)

TEMPLATE = '''
<!DOCTYPE html>
<html>
<head>
    <title>Heckers' Darkweb Dashboard</title>
    <style>
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #4CAF50; color: white; }
        img { max-width: 150px; max-height: 100px; }
    </style>
    <meta http-equiv="refresh" content="10">
</head>
<body>
    <h1>Heckers' Darkweb OSINT Crawl Results</h1>
    <table>
        <thead>
            <tr>
                <th>URL</th>
                <th>Active</th>
                <th>Blacklisted</th>
                <th>Keywords Found</th>
                <th>Title</th>
                <th>Screenshot</th>
                <th>Timestamp (UTC)</th>
            </tr>
        </thead>
        <tbody>
            {% for entry in results %}
            <tr>
                <td><a href="{{ entry.url }}" target="_blank">{{ entry.url }}</a></td>
                <td>{{ 'Yes' if entry.active else 'No' }}</td>
                <td>{{ 'Yes' if entry.blacklisted else 'No' }}</td>
                <td>{{ entry.keywords_found | join(', ') }}</td>
                <td>{{ entry.metadata.title }}</td>
                <td>
                    {% if entry.screenshot and entry.active %}
                    <a href="/screenshots/{{ entry.screenshot_filename }}" target="_blank">
                        <img src="/screenshots/{{ entry.screenshot_filename }}" alt="screenshot">
                    </a>
                    {% else %}
                    N/A
                    {% endif %}
                </td>
                <td>{{ entry.timestamp }}</td>
            </tr>
            {% endfor %}
        </tbody>
    </table>
    <p>Page refreshes every 10 seconds.</p>
</body>
</html>
'''

@app.route('/')
def index():
    results = []
    if os.path.exists(RESULTS_FILE):
        with open(RESULTS_FILE, 'r') as f:
            for line in f:
                try:
                    entry = json.loads(line)
                    entry['active'] = bool(entry.get('keywords_found') or entry.get('metadata', {}).get('title'))
                    entry['screenshot_filename'] = os.path.basename(entry.get('screenshot', ''))
                    results.append(entry)
                except json.JSONDecodeError:
                    continue
    return render_template_string(TEMPLATE, results=results)

@app.route('/screenshots/<path:filename>')
def screenshots(filename):
    return send_from_directory('outputs', filename)

def run_dashboard():
    print("Starting Flask dashboard at http://127.0.0.1:5000")
    app.run(host='127.0.0.1', port=5000, debug=False, use_reloader=False)

def handle_page(url, html):
    logging.info(f"Analyzing {url}")
    matched = analyzer.search_keywords(html, KEYWORDS)
    meta = analyzer.extract_metadata(html)
    is_malicious = threat_feed.check_blacklist(url)
    screenshot_path = f"outputs/{url.split('//')[-1].replace('/', '_')}.png"

    # Use crawler's screenshot method to reuse driver
    success = crawler.capture_screenshot(url, screenshot_path)
    if not success:
        logging.warning(f"Failed to capture screenshot for {url}")

    result = {
        'url': url,
        'keywords_found': list(matched.keys()),
        'metadata': meta,
        'blacklisted': is_malicious,
        'screenshot': screenshot_path if success else '',
        'timestamp': datetime.utcnow().isoformat()
    }

    with open(RESULTS_FILE, 'a') as f:
        f.write(json.dumps(result) + '\n')

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python main.py <start_onion_url>")
        sys.exit(1)

    start_url = sys.argv[1]
    if not is_valid_onion_url(start_url):
        print("[!] Invalid .onion URL.")
        sys.exit(1)

    if os.path.exists(RESULTS_FILE):
        os.remove(RESULTS_FILE)

    # Start Flask dashboard in background thread
    dashboard_thread = threading.Thread(target=run_dashboard, daemon=True)
    dashboard_thread.start()

    normalized_start_url = normalize_url(start_url)
    crawler = TorCrawler()
    try:
        crawler.crawl(normalized_start_url, 0, handle_page)
    finally:
        crawler.close()

    print("[✓] Crawling completed. Dashboard running at http://127.0.0.1:5000")
    logging.info("Crawling completed.")
    # Keep main thread alive to keep dashboard running
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print("\nExiting...")
        logging.info("Exiting on user interrupt.")
        crawler.close()
        sys.exit(0)
EOF

# requirements.txt
cat > darkweb-osint/requirements.txt << 'EOF'
requests
beautifulsoup4
selenium
stem
lxml
Flask
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
