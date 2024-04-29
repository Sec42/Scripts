import struct
import binascii
import datetime
import sys

fn = sys.argv[1]
fileext = { 0:'none',1:'gzip',2:'bzip2',3:'lzma',4:'lzo'}
fin = open(fn, "rb")
uimghdr = fin.read(64)
magic,        = struct.unpack("!i"   , uimghdr[ 0:4 ] )
headercrc32,  = struct.unpack("!I"   , uimghdr[ 4:8 ] )
timestamp,    = struct.unpack("!i"   , uimghdr[ 8:12] )
datasize,     = struct.unpack("!i"   , uimghdr[12:16] )
LoadAddress,  = struct.unpack("!i"   , uimghdr[16:20] )
EntryPtAddr,  = struct.unpack("!i"   , uimghdr[20:24] )
Datacrc32,    = struct.unpack("!I"   , uimghdr[24:28] )
OperatingSys, = struct.unpack("!b"   , uimghdr[28:29] )
Architecture, = struct.unpack("!b"   , uimghdr[29:30] )
ImageType,    = struct.unpack("!b"   , uimghdr[30:31] )
CompressType, = struct.unpack("!b"   , uimghdr[31:32] )
ImageName,    = struct.unpack("!32s" , uimghdr[32:64] )
uimgdata = fin.read(datasize)
fin.close()
copy = list(uimghdr)
copy[4:8] = b'\x00\x00\x00\x00' 
crcdata = bytearray(copy)
realhdrcrc32 = binascii.crc32(crcdata)
realdatacrc32 = binascii.crc32(uimgdata)
assert ( realhdrcrc32  == headercrc32 )
assert ( realdatacrc32 == Datacrc32 )
print ("UBoot Header Magic %s" % hex(magic))
print ("UBoot Header crc32 %s" % hex( realhdrcrc32))
print ("UBoot Header Tstmp %s" % datetime.datetime.fromtimestamp(timestamp))
print ("UBoot Header DSize %s" % hex(datasize))
print ("Uboot Compression  %s" % fileext[CompressType])
fout = open('%s.dump'%fn , 'wb')
fout.write(uimgdata)
fout.close()
