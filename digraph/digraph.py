#!/usr/bin/env python3
#coding:utf-8
"""
  Author:  Sir Garbagetruck --<truck@notonfire.co.uk>
  Purpose: tmux compose key
  Created: 19/12/14
"""
import sys
import re

#----------------------------------------------------------------------
def keynamelookup(key):
    """return the character for a descriptive key name"""
    table = {
        'space':           ' ',
        'period':          '.',
        'comma':           ',',
        'colon':           ':',
        'dead_tilde':      '~',
        'dead_acute':      '´',
        'apostrophe':      "\''",
        'dead_grave':      '`',
        'grave':           '`',
        'dead_circumflex': '^',
        'quotedbl':        '"',
        'less':            '<',
        'greater':         '>',
        'minus':           '-',
        'plus':            '+',
        'parenleft':       '[',
        'parenright':      ']',
        'slash':           "/",
        'backslash':       "\\",
        'exclam':          '!',
        'question':        '?',
        'asterisk':        '*',
        'percent':         '%',
        'equal':           '=',
        'numbersign':      '#',
        'diaeresis':       ':',
        'asciitilde':      '~',
#        'dead_currency':   'cur',
        'dead_belowcomma': ',,',
        'dead_abovedot':   ';',
        'asciicircum':     '^',
        'bar':             '|',
        'underbar':        '_',
        'dead_abovering':  'o',
        'dead_belowdot':   '..',
#        'dead_hook':       'hook',
#        'dead_horn':       'horn',
#        'dead_macron':     '=',
#        'dead_greek':      'greek',
#        'dead_ogonek':     'og',
        'underscore':      '_'
    }
    if len(key)==1:
        return key
    return table[key]

#----------------------------------------------------------------------
def breakout(line):
    """break out the keys and result given a utf8 key def line"""
    result = {}
    lside, _, rside = line.partition(':')

    stroke=""
    err=0
    keys=[]
    for key in lside.strip().split():
        if key.startswith("<"):
            if key == '<Multi_key>':
                continue
            keys.append(key)
            try:
                stroke+=keynamelookup(key.lstrip('<').rstrip('>'))
            except:
#                print("ERR(key):", key, "in", lside, file=sys.stderr)
                return None
        else:
            print("ERR:",key,"in",lside, file=sys.stderr)
            return None

    result['stroke']=stroke
    result['keys']=keys

    parse = re.fullmatch(r'\s*"([^"]*)"\s*([^#]*?)?(?:\s+#\s+(.*?))?\s*', rside)
    if not parse:
        print("ERR(rside):","'"+rside+"'")
        return None

    result['char']= parse.group(1)
    result['charname'] = parse.group(2)
    result['utf8name'] = parse.group(3)
    if result['char'] == '\\\\':
        result['char'] = '\\'

    if result['stroke'] == result['char']+result['char']:
        return None

    if result['stroke'] == result['char']+' ':
        return None

#    print(stroke,"->", result)
    return result

#----------------------------------------------------------------------
def utf8keys(input):
    """read in and return the utf8 x11 key defs"""
    f = open('/usr/share/X11/locale/en_US.UTF-8/Compose','r')
    r = f.read().splitlines()
    f.close()
    table = {}
    for i in r:
        if i.startswith('<'):
            result = breakout(i)
            if result is None:
                continue
            if result['stroke'] in table:
                if result['char'] != table[result['stroke']]['char']:
                    print("OVERWRITE: %s => %s // %s => %s"%(result['keys'],result['char'], table[result['stroke']]['keys'],table[result['stroke']]['char']))
            table[result['stroke']] = result

    if input == 'dump':
        res={}
        for i in sorted(table.values(), key= lambda k: ord(k['char'][-1])):
            print("%-5s"%("'"+i['stroke']+"'"),"=>",i['char'],"#","%-14s"%i['charname'],"("+i['utf8name']+")",i['keys'])
            res[i['char']]=1

        print("res:",len(res))
    else:
        try:
            print(table[input]['char'],end='')
        except:
            pass

#----------------------------------------------------------------------
def main(strokes):
    """given 2 keystrokes, return the utf8 character from the x11 file"""
    utf8keys(strokes)


if __name__ == '__main__':
    s = ""
    for i in sys.argv[1:]:
        s = s+i
    main(s)
