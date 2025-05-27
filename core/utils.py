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
