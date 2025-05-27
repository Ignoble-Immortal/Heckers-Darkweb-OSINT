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
