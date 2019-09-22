#!/bin/sh

oldsym=llc_api_crypto_disable_rx # Symbol to replace
newsym=llc_api_crypto_disable_tx # New symbol

func=BbBleDrvTxData # Search within this function 
hit=1               # Take the 1st hit

obj=bb_ble_drv.o # object file to edit

###
###
###

echo Working on ${obj}...
echo

oldid=$(readelf -Ws ${obj} |grep ${oldsym} | cut -d : -f1 )
newid=$(readelf -Ws ${obj} |grep ${newsym} | cut -d : -f1 )

oldhex=$(printf "%06x" $oldid)
newhex=$(printf "%06x" $newid)

h1=$(echo "${oldhex}"|cut -c 1-2)
h2=$(echo "${oldhex}"|cut -c 3-4)
h3=$(echo "${oldhex}"|cut -c 5-6)

oldrev=$h3$h2$h1

h1=$(echo "${newhex}"|cut -c 1-2)
h2=$(echo "${newhex}"|cut -c 3-4)
h3=$(echo "${newhex}"|cut -c 5-6)

newrev=$h3$h2$h1

echo Symbol table entries:
echo OLD: ${oldsym} = $oldid / $oldhex
echo NEW: ${newsym} = $newid / $newhex

# Relocation section '.rel.text.BbBleDrvSetChannelParam' at offset 0x3e720 contains 2 entries:

offhex=$(readelf -Wr ${obj} |grep "Relocation section .*${func}'"| sed 's/^.*offset //;s/ .*//')
off=$(echo "16i $(echo ${offhex#0x}|tr a-f A-F) p"|dc)

#readelf -Wr ${obj} | awk '/Relocation section .*'"${func}"'/{IN=1;COUNT=0;HIT='"${hit}"'};IN==1 {print;COUNT+=1};IN==1 && /'"${oldsym}"'/{HIT-=1;if(HIT==0){print} };/^$/{IN=0}'
idx=$(readelf -Wr ${obj} | awk '/Relocation section .*'"${func}"'/{IN=1;COUNT=-2;HIT='"${hit}"'};
IN==1 && /'"${oldsym}"'/{HIT-=1;if(HIT==0){print COUNT} };
IN==1 {COUNT+=1};
/^$/{IN=0}')

echo
echo Relocation table offset for ${func}: $off / $offhex

no=$(echo "$idx 8 * $off + 5+ p" |dc )

cur=$(dd if=${obj} count=3 bs=1 skip=${no} 2>/dev/null |xxd -g 4 -p)

echo
echo "Relocation table index for #${hit} of ${oldsym}: $idx"
echo
echo Offset in binary: ${no}, new value ${newrev}

if [ "$cur" -ne "$oldrev" ] ; then
	echo "Whoops. Found ${cur} instead of ${oldrev}"
    exit 1
fi

cp ${obj} ${obj}.new
echo $newrev | xxd -p -r | dd of=${obj}.new count=3 bs=1 seek=${no} conv=notrunc 2>/dev/null

echo Done. Patched file is ${obj}.new
