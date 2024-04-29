#!/usr/bin/env python3

import sys
import struct

with open(sys.argv[1], 'rb') as fh:
    ba = bytearray(fh.read())

def p_xd(start, l):
    """hexdump"""
    print("%x:" % start, end=" ")
    for x in range(start, start+l):
        print("%02x" % ba[x], end=" ")
    print()

def g4(addr):
    """unpack int"""
    return (struct.unpack("I", ba[addr:addr+4]))[0]

def g2(addr):
    """unpack short"""
    return (struct.unpack("H", ba[addr:addr+2]))[0]

def s(addr):
    """unpack string"""
    st = ba[addr:addr+32]
    i = st.find(b'\x00')
    return st[:i].decode("ascii")


print("file len=", len(ba))


a = 0x18
x = 0
while a < len(ba):
    nam = s(a+12)
    print("%d>>" % x, nam)

#    p_xd(a, 16)

    csum = g4(a)
    h = g2(a+4)
    if h > 4:
        print("- probably parsing incorrect")
        p_xd(a, 16)
        break
    ln1 = g2(a+6)
    ln2 = g4(a+8)
    print("csum: %04x type:%d hdr_len:0x%x data_len:0x%x" % (csum, h, ln1, ln2))
    if h == 4:
        print("- internal name:", s(a+0x24))

    # write file
    with open('%d_%s.bin' % (x, nam), 'wb') as w:
        w.write(ba[a+ln1:a+ln1+ln2])

    a = a+ln1+ln2
    if a%4 != 0: # fill up modulo 4
        a += 4-(a%4)

    print()
    x += 1

print("> EOF")
