"""import requests
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
        crawl(link, depth + 1, callback)"""

"""import logging
import time
from selenium import webdriver
from selenium.webdriver.firefox.options import Options
from selenium.common.exceptions import TimeoutException, WebDriverException
from urllib.parse import urljoin
from config import MAX_DEPTH, CRAWL_LIMIT
from core.utils import get_random_user_agent, is_valid_onion_url, normalize_url

CRAWLED_URLS = set()

def fetch_page(url, retries=3):
    options = Options()
    options.headless = True
    options.set_preference('network.proxy.type', 1)
    options.set_preference('network.proxy.socks', '127.0.0.1')
    options.set_preference('network.proxy.socks_port', 9050)
    options.set_preference("network.proxy.socks_remote_dns", True)
    options.set_preference("dom.webdriver.enabled", False)
    options.set_preference('useAutomationExtension', False)
    # Random user agent is tricky with Selenium; you can set it via profile if needed

    for attempt in range(retries):
        try:
            driver = webdriver.Firefox(options=options)
            driver.set_page_load_timeout(30)
            driver.get(url)
            time.sleep(5)  # wait for JS to load
            html = driver.page_source
            driver.quit()
            return html
        except (TimeoutException, WebDriverException) as e:
            logging.warning(f"Selenium error on {url}: {e}")
            try:
                driver.quit()
            except:
                pass
            time.sleep(2 ** attempt)
    return None

def extract_links(html, base_url):
    from bs4 import BeautifulSoup
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
    time.sleep(3)  # polite delay
    for link in extract_links(html, normalized_url):
        if len(CRAWLED_URLS) >= CRAWL_LIMIT:
            break
        crawl(link, depth + 1, callback)"""

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
