#!/usr/local/bin/perl -s

# arte_rtmpdump.pl
# - Simple script do simplify arte mediathek downloads
# - by Stefan `Sec` Zehl <sec@42.org>
# - Licence: BSD (2-clause)

use lib '../GET/';
our ($dwim);

# http://videos.arte.tv/de/videos/flaschenwahn_statt_wasserhahn-3775760.html
# http://www.ardmediathek.de/ard/servlet/content/3517136?documentId=5817888

$_=$ARGV[0];

use warnings;
use strict;
use GET;

GET::config (
		min_cache => 3000,
        );

my $body;
my $err;
my ($proto,$host,$app,$path);
my $name;
my $player;


if ($_ =~ /ardmediathek.de/){
	$body=GET::get_url($_, html => 1);
	#mediaCollection.addMediaStream(0, 1, "rtmp://swr.fcod.llnwd.net/a4332/e6/", "mp4:kultur/30-extra/alpha07/409171.m");

	$name = $body->find("h2")->content_array_ref()->[0];
	die "Can't find title tag\n" if ! defined $name;
	$name=~s!&.*?;!!g;
	$name=~y!0-9a-zA-Z -!!cd;
	$name=~s!\s*-\s*!-!g;
	$name=~s!\s+!_!g;
	$name="ARD-".$name.".flv";

	for( $body->look_down( _tag => "script")){
		next unless $_->content();
		next unless $_->content()->[0]=~ 
			m!mediaCollection.addMediaStream[^"]*"
			(rtmp)://([^/]*)/([^"]*)/",\s*"(mp4:[^"]*)"!ix;
		($proto,$host,$app,$path)=($1,$2,$3,$4);
	};

	die "Can't find stream URL" unless defined $proto;
	$path=~s!\.[sm]$!.l!; # Use better stream!
}else{


$body=GET::get_url($_, html => 1);

for( $body->look_down( _tag => "script")){
	next unless $_->content();
	$player=$1 if $_->content()->[0]=~/url_player\s*=\s*"([^"]*)/;
};
die "Can't find player URL\n" if !$player;

my $embed=$body->find("embed")->attr("src");
$embed=~ s/.*videorefFileUrl=//;
$embed=~s/&amp;/\&/g;
$embed=~s/%(..)/chr hex $1/ge;

#

my $doc=GET::get_url($embed, xml => 1);

my $url=${
			$doc->findnodes('//*/video[@lang="de"]/@ref')
		}[0] -> textContent;

if(!$url){
	die "Couldn't find second xml url\n";
};

my $doc2=GET::get_url($url, xml => 1);

$name= ${
			$doc2->findnodes('/video/name')
		}[0] -> textContent;

print "Video name: $name\n";

$name=~s! !_!g;
$name=~s/ä/ae/g; $name=~s/ö/oe/g; $name=~s/ü/ue/g;
$name=~s/Ä/Ae/g; $name=~s/Ö/Oe/g; $name=~s/Ü/Ue/g; $name=~s/ß/ss/g;
$name=~y!a-zA-Z_!!cd;
$name="ARTE-".$name.".flv";
my $url2=${
			$doc2->findnodes('//*/url[@quality="hd"]')
		}[0] -> textContent;

#print $url2,"\n";
#rtmp://artestras.fcod.llnwd.net/a3903/o35/MP4:geo/videothek/EUR_DE_FR/arteprod/A7_SGT_ENC_04_040261-000-A_PG_HQ_DE?h=404905af3f3096a4b903ca476b089063

if (!($url2=~ m!(rtmp)://([^/]*)/(.*)/(MP4:.*)!)){
	die "Can't match URL: $url2\n";
}; 

($proto,$host,$app,$path)=($1,$2,$3,$4);
};

if($player){
	$player="-W '$player' \\\n";
}else{
	$player="";
};


my $cmd= <<EOM ;
rtmpdump \\
--protocol '$proto' --host '$host' --app '$app' \\
--playpath '$path' \\
${player}--flv '$name'
EOM

print $cmd;

if ($dwim){
	system("echo $cmd");
};
