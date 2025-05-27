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
