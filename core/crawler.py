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
