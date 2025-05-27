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
