# Heckers' Darkweb OSINT Crawler

## Overview

This project is a Tor-based dark web crawler designed for authorized penetration testing and open-source intelligence (OSINT) gathering. It autonomously accesses and navigates `.onion` websites on the Tor network, detects active pages, captures real-time screenshots, and provides a live dashboard for monitoring crawl results.

The tool aids threat intelligence teams by visually archiving dark web content such as marketplaces, forums, and other sources of sensitive information not accessible through conventional means.

---

## Tools Used

- **Tor Network:** Provides anonymous access to `.onion` sites.
- **Selenium WebDriver with Firefox:** Automates browser interactions for crawling and screenshot capture.
- **Flask:** Hosts the local web dashboard for real-time monitoring.
- **BeautifulSoup & lxml**: For HTML parsing and link extraction.
- **Python 3:** Core programming language.
- **Geckodriver:** Firefox WebDriver executable.
- **Stem**: Python library to interact with and control the Tor process.

---

## Dependencies

All Python dependencies are listed in `requirements.txt`:

- Flask
- requests
- beautifulsoup4
- selenium
- stem
- lxml

Install them via:

```bash
pip install -r requirements.txt
```

---

## Prerequisites

- **Tor**: Ensure the Tor service is installed and running locally (default SOCKS proxy at `127.0.0.1:9050`).
- **Firefox Browser** (compatible with Selenium WebDriver)
- **Geckodriver**: Firefox WebDriver executable installed and in your system PATH.
- **Python 3.8+**

---

## Installation through Repository

1. Clone the repository:

   ```bash
   git clone https://github.com/Ignoble-Immortal/Heckers-Darkweb-OSINT.git
   cd darkweb-osint-crawler
   ```

2. Create and activate a Python virtual environment:

   ```bash
   python3 -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```

3. Install dependencies:

   ```bash
   pip install -r requirements.txt
   ```

4. Start the Tor service:

   - On Linux/macOS:

     ```bash
     tor &
     ```

   - On Windows, start Tor via the Tor Browser or Tor service.

---

## Installation through the provided bash script on Linux

1. Download the setup file from https://github.com/Ignoble-Immortal/Heckers-Darkweb-OSINT/blob/master/setup_darkweb_osint.sh

2. Open terminal where the file downloaded, make the file an executable and run it:

    ```bash
    chmod +x setup_darkweb_osint.sh
    ./setup_darkweb_osint.sh
    ```
3. Follow the steps given by the script on console.

---

## Usage

Run the crawler with a starting `.onion` URL:

```bash
python3 main.py <onion_url>
```

Example:

```bash
python3 main.py http://exampleonionaddress.onion
```

- The crawler will begin fetching pages through Tor, capturing screenshots, and analyzing content.
- A local web dashboard will be available at [http://127.0.0.1:5000](http://127.0.0.1:5000), updating live with crawl results.
- The dashboard displays URLs, active status, blacklist flags, keywords found, page titles, and screenshots.

---

## Configuration

- Modify `config.py` to adjust crawl depth, crawl limits, keywords, and blacklist sources.
- Logs are saved in `data/logs/activity.log`.
- Crawl results and screenshots are saved in the `outputs/` directory.

---

## Screenshots

![Dashboard Screenshot](https://github.com/user-attachments/assets/ae148de2-2005-4f20-bba2-cbcd00197d0c)

![Crawler Screenshot](https://github.com/user-attachments/assets/a673e7aa-2ce4-434d-abaf-da530b59b955)

---

## YouTube Demo Preview

[![Watch the demo](https://github.com/user-attachments/assets/abc896a0-c21c-4647-99b9-ce9b7c24af9b)](https://www.youtube.com/watch?v=RXVBT_HXq7w)

This demo showcases the core functionality and features we've implemented
to effectively crawl and extract data from the dark web while
maintaining anonymity and security.

---

## Security and Ethics

**Important:** This tool is intended for use **only with explicit authorization**. Unauthorized crawling or scanning of the dark web may violate laws and ethical guidelines.

Always ensure you have permission from your organization or governing body before deploying this tool. Respect privacy, avoid disruption, and use responsibly.

---

Thank you for using the Heckers' Darkweb OSINT Crawler.
