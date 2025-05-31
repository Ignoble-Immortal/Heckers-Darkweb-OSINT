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