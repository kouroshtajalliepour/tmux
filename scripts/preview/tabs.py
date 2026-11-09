#!/usr/bin/env python3
"""Control the tabs of the preview Firefox through its local Marionette port.

  tabs.py [--port N] list         one URL per line, "* " marks the active tab
  tabs.py [--port N] active       the active tab's URL
  tabs.py [--port N] show URL     focus the tab on URL's host and port, without
                                  reloading it, or open one. Prints what it did
  tabs.py [--port N] goto URL     take that tab to URL, or open one

Exit codes: 0 ok, 3 Firefox can't be reached, 1 anything else.
"""
import argparse
import json
import socket
import sys
from urllib.parse import urlsplit

LOCAL_HOSTS = {"localhost", "127.0.0.1", "[::1]", "::1"}


class Unreachable(Exception):
    pass


class Marionette:
    def __init__(self, port, timeout=10):
        try:
            self.sock = socket.create_connection(("127.0.0.1", port), timeout=timeout)
        except OSError as err:
            raise Unreachable(str(err)) from err
        self.buf = b""
        self.msg_id = 0
        self._read()  # the server's hello
        self.call(
            "WebDriver:NewSession",
            {"capabilities": {"alwaysMatch": {"pageLoadStrategy": "none"}}},
        )

    def _read(self):
        while b":" not in self.buf:
            self._fill()
        head, self.buf = self.buf.split(b":", 1)
        size = int(head)
        while len(self.buf) < size:
            self._fill()
        body, self.buf = self.buf[:size], self.buf[size:]
        return json.loads(body)

    def _fill(self):
        chunk = self.sock.recv(65536)
        if not chunk:
            raise Unreachable("connection closed")
        self.buf += chunk

    def call(self, name, params=None):
        self.msg_id += 1
        body = json.dumps([0, self.msg_id, name, params or {}]).encode()
        self.sock.sendall(str(len(body)).encode() + b":" + body)
        reply = self._read()
        if reply[2]:
            raise RuntimeError(f"{name}: {reply[2].get('message', reply[2])}")
        return reply[3]

    def close(self):
        try:
            self.call("WebDriver:DeleteSession")
        finally:
            self.sock.close()

    def active(self):
        return self.call("WebDriver:GetWindowHandle")["value"]

    def url_of(self, handle):
        self.call("WebDriver:SwitchToWindow", {"handle": handle, "focus": False})
        return self.call("WebDriver:GetCurrentURL")["value"]

    def tabs(self):
        """Every tab as (handle, url). Leaves the session on the active tab."""
        active = self.active()
        handles = self.call("WebDriver:GetWindowHandles")
        result = [(h, self.url_of(h)) for h in handles]
        self.call("WebDriver:SwitchToWindow", {"handle": active, "focus": False})
        return active, result


def same_place(a, b):
    """Same host and port, treating every loopback name as one host."""
    a, b = urlsplit(a), urlsplit(b)
    if a.port != b.port:
        return False
    if a.hostname in LOCAL_HOSTS and b.hostname in LOCAL_HOSTS:
        return True
    return a.hostname == b.hostname


def show(m, url):
    _, tabs = m.tabs()
    for handle, current in tabs:
        if same_place(current, url):
            m.call("WebDriver:SwitchToWindow", {"handle": handle, "focus": True})
            return "focused"
    handle = m.call("WebDriver:NewWindow", {"type": "tab", "focus": True})["handle"]
    m.call("WebDriver:SwitchToWindow", {"handle": handle, "focus": True})
    m.call("WebDriver:Navigate", {"url": url})
    return "opened"


def goto(m, url):
    """Take the tab on URL's host and port to URL, or open one. A tab already
    on exactly URL is only focused, not reloaded."""
    _, tabs = m.tabs()
    for handle, current in tabs:
        if same_place(current, url):
            m.call("WebDriver:SwitchToWindow", {"handle": handle, "focus": True})
            if current == url:
                return "focused"
            m.call("WebDriver:Navigate", {"url": url})
            return "navigated"
    return show(m, url)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=2828)
    parser.add_argument("command", choices=["list", "active", "show", "goto"])
    parser.add_argument("url", nargs="?")
    args = parser.parse_args()
    if args.command in ("show", "goto") and not args.url:
        parser.error(f"{args.command} needs a URL")

    try:
        m = Marionette(args.port)
    except Unreachable as err:
        print(f"Firefox not reachable on port {args.port}: {err}", file=sys.stderr)
        return 3
    try:
        if args.command == "list":
            active, tabs = m.tabs()
            for handle, url in tabs:
                print(("* " if handle == active else "  ") + url)
        elif args.command == "active":
            print(m.url_of(m.active()))
        elif args.command == "goto":
            print(goto(m, args.url))
        else:
            print(show(m, args.url))
    except (RuntimeError, Unreachable, OSError, ValueError) as err:
        print(err, file=sys.stderr)
        return 1
    finally:
        try:
            m.close()
        except (RuntimeError, Unreachable, OSError, ValueError):
            pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
