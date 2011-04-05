// ==UserScript==
// @name           Arte-rtmpdump
// @namespace      http://sec.42.org/artedump
// @description    Outputs rtmpdump commandline for arte video download
// @include        http://videos.arte.tv/*
// ==/UserScript==

function _dwim() {

if (!unsafeWindow.vars_player)
	return;
var xmlurl= unsafeWindow.vars_player.videorefFileUrl;
var plyurl= unsafeWindow.url_player;

xmlhttp = new XMLHttpRequest();
xmlhttp.open("GET", xmlurl, false);
xmlhttp.send(null)

var v=xmlhttp.responseXML.documentElement.getElementsByTagName("video");

for (i=0;i<v.length;i++){
  if(v[i].getAttribute("lang") == "de")
    url=v[i].getAttribute("ref");
}

if(!url) return;

xmlhttp.open("GET", url, false);
xmlhttp.send(null);
var title= xmlhttp.responseXML.documentElement.getElementsByTagName("name")[0].childNodes[0].nodeValue;

var v= xmlhttp.responseXML.documentElement.getElementsByTagName("url");

for (i=0;i<v.length;i++){
  if(v[i].getAttribute("quality") == "hd")
    url=v[i].childNodes[0].nodeValue;
}

var re=url.match(/(rtmp):\/\/([^/]*)\/(.*)\/(MP4:.*)/)
var proto=re[1];
var host=re[2];
var app=re[3];
var path=re[4];

var str="rtmpdump" + " " +
"--protocol '" + proto + "' " +
"--host '"     + host  + "' " +
"--app '"      + app   + "' " +
"--playpath " + "\\<br>" +"'" + path  + "' " +"\\<br>"+
"-W '"         + plyurl + "' " +
"--flv 'ARTE-" + title + ".flv' ";

var note=document.getElementById("FetchNote");
if(!note){
 note=document.createElement("div");
 note.id="FetchNote";
 document.body.appendChild(note);
}

note.innerHTML=str;
note.style.position="fixed";
note.style.top="2em";
note.style.right="0";
note.style.background="#444";
note.style.border="solid 1px red";
note.style.width="auto";
note.style.padding="1em";
note.style.display="block";
//note.onclick=function(){note.style.display="none"};

};

_dwim();
