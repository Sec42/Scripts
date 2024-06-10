#!/usr/bin/env python3
"""Read ics file and print text representation"""

import argparse
from icalendar import Calendar

parser = argparse.ArgumentParser()

parser.add_argument("-f", "--full",     action="store_true",
                    help="print description if present")

parser.add_argument("ics", type=argparse.FileType('rb'))

args = parser.parse_args()

gcal = Calendar.from_ical(args.ics.read())
for component in gcal.walk('VEVENT'):
    start = component.get('dtstart')
    end = component.get('dtend')
    summary = component.get('summary')
    txt = component.get('description')
    if end is not None:
        print(f"{start.dt}-{end.dt}: {summary}")
    else:
        print(f"{start.dt}: {summary}")
    if args.full and txt is not None and txt != "":
        txt = "> "+txt.replace("\n", "\n> ")
        print(txt)
        print("")
