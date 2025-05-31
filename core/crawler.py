

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
