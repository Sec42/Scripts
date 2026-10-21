#!/usr/bin/env python3
"""Extract schema.org ld+json reservations from an email and emit iCalendar.

Usage: ldjson2ics [mailfile]   (reads stdin if no file given, writes ICS to stdout)
"""
import argparse
import datetime as dt
import email
import email.policy
import hashlib
import html
import json
import re
import sys

LDJSON_RE = re.compile(
    r'<script[^>]*type\s*=\s*["\']?application/ld\+json["\']?[^>]*>(.*?)</script>',
    re.I | re.S)


def text_parts(raw):
    """Yield decoded text of all text/* parts (or the whole thing if not MIME)."""
    msg = email.message_from_bytes(raw, policy=email.policy.default)
    found = False
    for part in msg.walk():
        if part.get_content_maintype() == "text":
            try:
                yield part.get_content()
                found = True
            except Exception:
                pass
    if not found:
        yield raw.decode("utf-8", "replace")


def ld_objects(raw):
    seen = set()
    for text in text_parts(raw):
        for blob in LDJSON_RE.findall(text):
            blob = blob.strip()
            try:
                data = json.loads(blob)
            except json.JSONDecodeError:
                try:
                    data = json.loads(html.unescape(blob))
                except json.JSONDecodeError as e:
                    print(f"ldjson2ics: skipping unparsable block: {e}", file=sys.stderr)
                    continue
            items = data if isinstance(data, list) else data.get("@graph", [data])
            for obj in items:
                key = json.dumps(obj, sort_keys=True)
                if key not in seen:  # same block often appears in text and html part
                    seen.add(key)
                    yield obj


def typ(obj):
    t = obj.get("@type", "") if isinstance(obj, dict) else ""
    return t[0] if isinstance(t, list) else t


def name_of(x):
    if isinstance(x, dict):
        return x.get("name") or x.get("iataCode") or ""
    return x or ""


def address_of(place):
    if not isinstance(place, dict):
        return place or ""
    addr = place.get("address", "")
    if isinstance(addr, dict):
        parts = [addr.get("streetAddress"),
                 " ".join(filter(None, [addr.get("postalCode"), addr.get("addressLocality")])),
                 addr.get("addressRegion"), name_of(addr.get("addressCountry"))]
        addr = ", ".join(p for p in parts if p)
    return ", ".join(p for p in [place.get("name"), addr] if p)


def parse_when(s):
    """Return a date (all-day) or datetime (aware -> UTC, naive -> floating)."""
    if not s:
        return None
    s = s.strip().replace("Z", "+00:00")
    if re.fullmatch(r"\d{4}-\d{2}-\d{2}", s):
        return dt.date.fromisoformat(s)
    d = dt.datetime.fromisoformat(s)
    return d.astimezone(dt.timezone.utc) if d.tzinfo else d


def reservation_to_event(r):
    t = typ(r)
    f = r.get("reservationFor") or {}
    ev = {"summary": None, "start": None, "end": None, "location": "", "desc": []}

    if t == "LodgingReservation":
        ev["summary"] = f"Hotel: {name_of(f)}"
        ev["start"] = parse_when(r.get("checkinDate") or r.get("checkinTime"))
        ev["end"] = parse_when(r.get("checkoutDate") or r.get("checkoutTime"))
        ev["location"] = address_of(f)
        if isinstance(ev["end"], dt.date) and not isinstance(ev["end"], dt.datetime):
            ev["end"] += dt.timedelta(days=1)  # DTEND is exclusive; show checkout day too
        if f.get("telephone"):
            ev["desc"].append(f"Phone: {f['telephone']}")
    elif t == "FlightReservation":
        dep, arr = f.get("departureAirport") or {}, f.get("arrivalAirport") or {}
        al = f.get("airline") or {}
        num = f"{al.get('iataCode', '') if isinstance(al, dict) else ''}{f.get('flightNumber', '')}"
        ev["summary"] = f"Flight {num}: {name_of(dep)} → {name_of(arr)}".replace("  ", " ")
        ev["start"], ev["end"] = parse_when(f.get("departureTime")), parse_when(f.get("arrivalTime"))
        ev["location"] = address_of(dep)
        if r.get("reservedTicket", {}).get("ticketedSeat"):
            ev["desc"].append(f"Seat: {r['reservedTicket']['ticketedSeat'].get('seatNumber', '')}")
    elif t in ("TrainReservation", "BusReservation"):
        dep = f.get("departureStation") or f.get("departureBusStop") or {}
        arr = f.get("arrivalStation") or f.get("arrivalBusStop") or {}
        kind = "Train" if t == "TrainReservation" else "Bus"
        num = f.get("trainNumber") or f.get("busNumber") or ""
        ev["summary"] = f"{kind} {num}: {name_of(dep)} → {name_of(arr)}".replace("  ", " ")
        ev["start"], ev["end"] = parse_when(f.get("departureTime")), parse_when(f.get("arrivalTime"))
        ev["location"] = address_of(dep)
    elif t == "RentalCarReservation":
        ev["summary"] = f"Rental car: {name_of(f.get('rentalCompany') or f)}"
        ev["start"], ev["end"] = parse_when(r.get("pickupTime")), parse_when(r.get("dropoffTime"))
        ev["location"] = address_of(r.get("pickupLocation"))
    elif t == "FoodEstablishmentReservation":
        ev["summary"] = f"Dinner: {name_of(f)}"
        ev["start"], ev["end"] = parse_when(r.get("startTime")), parse_when(r.get("endTime"))
        ev["location"] = address_of(f)
        if r.get("partySize"):
            ev["desc"].append(f"Party size: {r['partySize']}")
    else:  # EventReservation and anything else with a dated reservationFor
        ev["summary"] = name_of(f) or t
        ev["start"] = parse_when(f.get("startDate") or r.get("startTime"))
        ev["end"] = parse_when(f.get("endDate") or r.get("endTime"))
        ev["location"] = address_of(f.get("location") or {})

    if not ev["start"]:
        return None
    if not ev["end"]:
        ev["end"] = (ev["start"] + dt.timedelta(days=1) if not isinstance(ev["start"], dt.datetime)
                     else ev["start"] + dt.timedelta(hours=1))
    if r.get("reservationNumber"):
        ev["desc"].insert(0, f"Reservation: {r['reservationNumber']}")
    status = r.get("reservationStatus", "")
    if status:
        ev["desc"].append(f"Status: {status.rsplit('/', 1)[-1]}")
    if r.get("underName"):
        ev["desc"].append(f"Guest: {name_of(r['underName'])}")
    ev["cancelled"] = "Cancelled" in status
    # stable UID so re-importing the same (or an updated) confirmation overwrites the event
    key = f"{t}|{r.get('reservationNumber') or ''}|{ev['summary']}"
    if not r.get("reservationNumber"):
        key += f"|{ev['start']}"
    ev["uid"] = hashlib.sha1(key.encode()).hexdigest() + "@ldjson2ics"
    return ev


def esc(s):
    return (s.replace("\\", "\\\\").replace(";", "\\;").replace(",", "\\,")
            .replace("\n", "\\n"))


def fold(line):
    b = line.encode()
    out = []
    while len(b) > 75:
        cut = 75 if not out else 74
        while (b[cut] & 0xC0) == 0x80:  # don't split UTF-8 sequences
            cut -= 1
        out.append(b[:cut].decode())
        b = b[cut:]
    out.append(b.decode())
    return "\r\n ".join(out)


def fmt_when(prop, d):
    if isinstance(d, dt.datetime):
        z = "Z" if d.tzinfo else ""
        return f"{prop}:{d.strftime('%Y%m%dT%H%M%S')}{z}"
    return f"{prop};VALUE=DATE:{d.strftime('%Y%m%d')}"


def to_ics(events):
    now = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    lines = ["BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//ldjson2ics//EN", "CALSCALE:GREGORIAN"]
    for ev in events:
        lines += ["BEGIN:VEVENT", f"UID:{ev['uid']}", f"DTSTAMP:{now}",
                  fmt_when("DTSTART", ev["start"]), fmt_when("DTEND", ev["end"]),
                  f"SUMMARY:{esc(ev['summary'])}"]
        if ev["location"]:
            lines.append(f"LOCATION:{esc(ev['location'])}")
        if ev["desc"]:
            lines.append(f"DESCRIPTION:{esc(chr(10).join(ev['desc']))}")
        lines.append("STATUS:CANCELLED" if ev["cancelled"] else "STATUS:CONFIRMED")
        if isinstance(ev["start"], dt.date) and not isinstance(ev["start"], dt.datetime):
            lines.append("TRANSP:TRANSPARENT")  # all-day stay shouldn't block the calendar
        lines.append("END:VEVENT")
    lines.append("END:VCALENDAR")
    return "".join(fold(l) + "\r\n" for l in lines)


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("mail", nargs="?", help="mail file (default: stdin)")
    args = ap.parse_args()
    raw = open(args.mail, "rb").read() if args.mail else sys.stdin.buffer.read()

    events = []
    for obj in ld_objects(raw):
        if typ(obj).endswith("Reservation"):
            ev = reservation_to_event(obj)
            if ev:
                events.append(ev)
    if not events:
        print("ldjson2ics: no reservation found", file=sys.stderr)
        return 1
    sys.stdout.buffer.write(to_ics(events).encode())
    return 0


if __name__ == "__main__":
    sys.exit(main())
