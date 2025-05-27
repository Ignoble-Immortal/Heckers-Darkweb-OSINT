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
