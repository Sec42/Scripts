#!/usr/bin/env python3
"""Upload the events of an .ics file to a CalDAV calendar collection.

Usage: ics2caldav [-n] [-u URL] [-U USER] [-c CALENDAR] [file.ics]
       ics2caldav -l [-u URL] [-U USER]          list calendars

URL may be the server (https://dav.example.org/), any DAV URL on it, or the
calendar collection itself. With -c the calendar is looked up by name (via
/.well-known/caldav, current-user-principal, calendar-home-set); without -c
URL must be a calendar, or the account must have only one.

Each UID becomes its own resource <collection>/<uid>.ics; uploading again
overwrites it. Config (~/.config/ics2caldav, KEY=value lines) or environment:
  CALDAV_URL       see above (CALDAV_BASE is accepted as well)
  CALDAV_CALENDAR  calendar display name (or last path component)
  CALDAV_USER      user name                /  if unset, ~/.netrc is used;
  CALDAV_PASSCMD   command printing password /  password is asked for if missing
"""
import argparse
import base64
import getpass
import netrc
import os
import re
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET

CONFIG = os.path.expanduser("~/.config/ics2caldav")
NS = {"d": "DAV:", "c": "urn:ietf:params:xml:ns:caldav"}


def load_config():
    cfg = {}
    if os.path.exists(CONFIG):
        for line in open(CONFIG):
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, v = line.split("=", 1)
                cfg[k.strip()] = v.strip().strip('"\'')
    cfg.update({k: v for k, v in os.environ.items() if k.startswith("CALDAV_")})
    return cfg


def credentials(cfg, url):
    user, pw = cfg.get("CALDAV_USER"), cfg.get("CALDAV_PASS")
    if not user:
        try:
            auth = netrc.netrc().authenticators(urllib.parse.urlsplit(url).hostname)
            if auth:
                return auth[0], auth[2]
        except (FileNotFoundError, netrc.NetrcParseError):
            pass
        return None
    if not pw and cfg.get("CALDAV_PASSCMD"):
        pw = subprocess.run(cfg["CALDAV_PASSCMD"], shell=True, check=True,
                            capture_output=True, text=True).stdout.split("\n")[0]
    if not pw:
        pw = getpass.getpass(f"CalDAV password for {user}: ")  # prompts on /dev/tty
    return user, pw


class Dav:
    def __init__(self, auth):
        self.headers = {}
        if auth:
            tok = base64.b64encode(f"{auth[0]}:{auth[1]}".encode()).decode()
            self.headers["Authorization"] = f"Basic {tok}"

    def request(self, method, url, body=None, headers=None):
        """Return (final url, response); follows redirects for all methods."""
        h = dict(self.headers, **(headers or {}))
        for _ in range(5):
            req = urllib.request.Request(url, data=body, method=method, headers=h)
            try:
                return url, urllib.request.urlopen(req)
            except urllib.error.HTTPError as e:
                if e.code not in (301, 302, 303, 307, 308) or "Location" not in e.headers:
                    e.method = method
                    raise
                url = urllib.parse.urljoin(url, e.headers["Location"])
        raise urllib.error.URLError(f"too many redirects at {url}")

    def propfind(self, url, props, depth=0):
        """Return (final url, [(href, {prop tag: element})]) for 200-propstats."""
        body = ('<?xml version="1.0" encoding="utf-8"?>'
                '<d:propfind xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">'
                f'<d:prop>{"".join(f"<{p}/>" for p in props)}</d:prop></d:propfind>')
        url, resp = self.request("PROPFIND", url, body.encode(), {
            "Depth": str(depth), "Content-Type": "application/xml; charset=utf-8"})
        out = []
        for r in ET.fromstring(resp.read()).findall("d:response", NS):
            href = urllib.parse.urljoin(url, r.findtext("d:href", "", NS).strip())
            found = {}
            for ps in r.findall("d:propstat", NS):
                if " 200 " in ps.findtext("d:status", "", NS):
                    found.update({p.tag: p for p in ps.find("d:prop", NS)})
            out.append((href, found))
        return url, out

    def href_prop(self, url, prop):
        """Look up a single href-valued property (e.g. d:current-user-principal)."""
        tag = "{%s}%s" % (NS[prop.split(":")[0]], prop.split(":")[1])
        url, res = self.propfind(url, [prop])
        for _, props in res:
            href = props.get(tag) is not None and props[tag].findtext("d:href", None, NS)
            if href:
                return urllib.parse.urljoin(url, href.strip())
        return None


def http_error(e):
    """Describe an HTTPError including the server's explanation, if any."""
    msg = f"{getattr(e, 'method', '')} {e.url}: HTTP {e.code} {e.reason}".lstrip()
    try:
        body = e.read().decode("utf-8", "replace")
    except Exception:
        body = ""
    body = " ".join(re.sub(r"<\?xml[^>]*\?>", "", body).split())
    return f"{msg}\n  server said: {body[:600]}" if body else msg


def is_calendar(dav, url):
    try:
        _, res = dav.propfind(url, ["d:resourcetype"])
    except urllib.error.HTTPError as e:
        if e.code == 401:
            raise
        return False
    rtype = res[0][1].get("{DAV:}resourcetype") if res else None
    return rtype is not None and rtype.find("c:calendar", NS) is not None


def calendars(dav, base):
    """Discover the user's calendar collections: [(displayname, url)]."""
    starts = [base]
    if urllib.parse.urlsplit(base).path in ("", "/"):
        starts.insert(0, urllib.parse.urljoin(base, "/.well-known/caldav"))
    principal = None
    for s in starts:
        try:
            principal = dav.href_prop(s, "d:current-user-principal")
        except urllib.error.HTTPError as e:
            if e.code == 401:
                raise
            continue
        if principal:
            break
    home = dav.href_prop(principal or base, "c:calendar-home-set") or principal or base
    _, res = dav.propfind(home, ["d:displayname", "d:resourcetype"], depth=1)
    cals = []
    for href, props in res:
        rtype = props.get("{DAV:}resourcetype")
        if rtype is not None and rtype.find("c:calendar", NS) is not None:
            name = (props.get("{DAV:}displayname") is not None
                    and props["{DAV:}displayname"].text) or ""
            cals.append((name.strip(), href))
    return cals


def find_calendar(cals, name):
    want = name.casefold()
    for disp, url in cals:
        seg = urllib.parse.unquote(url.rstrip("/").rsplit("/", 1)[-1])
        if want in (disp.casefold(), seg.casefold()):
            return url
    avail = ", ".join(d or u for d, u in cals) or "none"
    sys.exit(f"ics2caldav: calendar {name!r} not found (available: {avail})")


def split_by_uid(ics):
    """Return {uid: single-object VCALENDAR text}, keeping VTIMEZONEs in each."""
    lines = re.sub(r"\r?\n[ \t]", "", ics).splitlines()  # unfold
    header, timezones, comps = [], [], []
    cur, depth, kind = None, 0, None
    for l in lines:
        if depth == 0 and l.startswith("BEGIN:") and l != "BEGIN:VCALENDAR":
            kind, cur = l[6:], []
        if cur is not None:
            cur.append(l)
            depth += l.startswith("BEGIN:") - l.startswith("END:")
            if depth == 0:
                (timezones if kind == "VTIMEZONE" else comps).append(cur)
                cur = None
        elif l not in ("BEGIN:VCALENDAR", "END:VCALENDAR"):
            header.append(l)
    out = {}
    for c in comps:
        uid = next((l.split(":", 1)[1] for l in c if l.startswith("UID:")), None)
        if uid is None:
            sys.exit("ics2caldav: component without UID")
        out.setdefault(uid, []).extend(c)  # recurrence overrides share a UID
    return {uid: "\r\n".join(["BEGIN:VCALENDAR", *header, *sum(timezones, []), *c,
                               "END:VCALENDAR"]) + "\r\n"
            for uid, c in out.items()}


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("ics", nargs="?", help="ics file (default: stdin)")
    ap.add_argument("-u", "-b", "--url", help="server or calendar URL (CALDAV_URL)")
    ap.add_argument("-U", "--user", help="user name (CALDAV_USER)")
    ap.add_argument("-c", "--calendar", help="calendar name (CALDAV_CALENDAR)")
    ap.add_argument("-l", "--list", action="store_true", help="list calendars and exit")
    ap.add_argument("-n", "--dry-run", action="store_true", help="only show what would be done")
    args = ap.parse_args()

    cfg = load_config()
    for opt, key in (("url", "CALDAV_URL"), ("user", "CALDAV_USER"),
                     ("calendar", "CALDAV_CALENDAR")):
        if getattr(args, opt):
            cfg[key] = getattr(args, opt)
    base = cfg.get("CALDAV_URL") or cfg.get("CALDAV_BASE")
    if not base:
        sys.exit(f"ics2caldav: no URL given (-u, CALDAV_URL in env or {CONFIG})")
    if not args.list:  # read before a password prompt might want the terminal
        ics = open(args.ics, encoding="utf-8").read() if args.ics else sys.stdin.read()

    try:
        dav = Dav(credentials(cfg, base))
        name = cfg.get("CALDAV_CALENDAR")
        if not args.list and not name and is_calendar(dav, base):
            collection = base
        else:
            cals = calendars(dav, base)
            if args.list:
                for disp, url in cals:
                    print(f"{disp}\t{url}")
                return 0
            if name:
                collection = find_calendar(cals, name)
            elif len(cals) == 1:
                collection = cals[0][1]
            else:
                avail = ", ".join(d or u for d, u in cals) or "none"
                sys.exit(f"ics2caldav: {base} is not a calendar; choose one with -c "
                         f"(available: {avail})")
    except urllib.error.HTTPError as e:
        sys.exit(f"ics2caldav: discovery failed: {http_error(e)}")
    except urllib.error.URLError as e:
        sys.exit(f"ics2caldav: discovery failed: {e.reason}")
    collection = collection.rstrip("/") + "/"

    rc = 0
    for uid, body in split_by_uid(ics).items():
        summary = next((l[8:] for l in body.splitlines() if l.startswith("SUMMARY:")), uid)
        url = collection + urllib.parse.quote(uid, safe="") + ".ics"
        if args.dry_run:
            print(f"would PUT {url}  ({summary})")
            continue
        try:
            _, resp = dav.request("PUT", url, body.encode(),
                                  {"Content-Type": "text/calendar; charset=utf-8"})
            print(f"{'created' if resp.status == 201 else 'updated'}: {summary}")
        except urllib.error.HTTPError as e:
            print(f"ics2caldav: {summary}: {http_error(e)}", file=sys.stderr)
            rc = 1
        except urllib.error.URLError as e:
            print(f"ics2caldav: {url}: {e.reason}", file=sys.stderr)
            rc = 1
    return rc


if __name__ == "__main__":
    sys.exit(main())
