#!/usr/local/bin/perl -s

# getFilme.pl
# - by Stefan `Sec` Zehl <sec@42.org>
# - Licence: BSD (3-clause)

use lib '../GET/';

use Data::Dumper;
use warnings;
use strict;
use GET;

our($v);

# Ignore "_parent" keys in HTML::Element dumping
$Data::Dumper::Sortkeys = sub {
	return [ (grep { $_ ne "_parent"} keys %{$_[0]}) ];
};


GET::config (
		min_cache => 3000,
        );

my($body);

$body=GET::get_url("http://m.filmfest-muenchen.de/de/filmprogramm/uebersicht/film-abc.aspx?selector=%",
		html => 1);

open(XML,">:utf8","ffm2011.xml");

print XML qq!<?xml version="1.0" encoding="UTF-8"?>\n!;
print XML qq!<ffm year="2011">\n!;

my (%locs,%secs);

for( $body->look_down( _tag => "li")){
	my($title,$link,$id);
	print "* " if ($v);

	$title=$_->look_down( _tag => "a");
	print "Title: ",$title->content()->[0],"\n" if ($v);

	$link=$title->attr("href");
	print "Link: $link\n" if ($v);

	$link=~/=(\d+)/;
	$id=$1;

	print XML "<film id=$id>\n";

	print "Otitle: ",$_->look_down( _tag => "p")->content()->[0],"\n" if ($v);
	print "Image: ", $_->attr("style"),"\n" if ($v);
	print "\n" if($v);

	my ($film,$img,$info,$cat,$txt,$screen);
	$film=GET::get_url("http://m.filmfest-muenchen.de${link}", html => 1);

	$img=$film->look_down ( class=> "m_filmDetailImage");
	if(defined$img){
		$img=$img->attr("src");
		print "* Image: $img\n" if ($v);
	};

	$info=$film->look_down ( class=> "m_filmDetailInfoLeft")->content();
	print "* Title1: ",$info->[0]->as_trimmed_text,"\n" if ($v);
	print "* Title2: ",$info->[1]->as_trimmed_text,"\n" if ($v);
	print "* Title3: ",$info->[2]->as_trimmed_text,"\n" if ($v);
	print "* Title4: ",$info->[3]->as_trimmed_text,"\n" if ($v);
	print "* Title5: ",$info->[4]->as_trimmed_text,"\n" if ($v && $info->[4]);
	print "* Title6: ",$info->[5]->as_trimmed_text,"\n" if ($v && $info->[5]);
	
	print XML "<title>",$info->[0]->as_trimmed_text,"</title>\n";
	my $t=$info->[1]->as_trimmed_text;
	$t=~s/^\s*\(//;$t=~s/\)\s*$//;
	print XML "<original-title>$t</original-title>\n";

	$cat=$film->look_down(class=> "m_filmDetailInfoLeft")->look_down(_tag=>"a");
	print "* Reihe: ",$cat->as_trimmed_text," : ",$cat->attr("href"),"\n" if ($v);
	my $sec=$cat->as_trimmed_text;
	$secs{$sec}=keys(%secs)+1 if(!defined $secs{$sec});
	print XML "<section>",$secs{$sec},"</section>\n";

	$txt=$film->look_down ( _tag => "td", colspan => "2");
	print "* Txt: ",$txt->content->[1]->as_HTML,"\n" if ($v && $txt->content->[1]);
	print XML "<details>",$txt->as_trimmed_text,"</details>\n";

	print XML "<url>",$link,"</url>\n";
	print XML "<img>",$img,"</img>\n" if defined($img);

	$screen=$film->look_down ( _tag => "ul", class => "m_list m_noimage");

	print XML "</film>\n";

	for my $idx ($screen->look_down(_tag=>"li")){
		my($day,$time,$loc);

		print "* When: ",($idx->content->[0]->content->[0]),"\n" if ($v);
		print "* Where: ",($idx->content->[0]->content->[2]->as_trimmed_text),"\n" if ($v);
		print XML "<screening><film>$id</film>\n";
		(undef,$day,$time)=split(/\x{a0}/,$idx->content->[0]->content->[0]);
		$day=~s/(\d+)\.(\d+)\.(\d+),/$3-$2-$1/;

		$loc=$idx->content->[0]->content->[2]->as_trimmed_text;
		$locs{$loc}=keys(%locs)+1 if(!defined $locs{$loc});

		print XML "<date>$day</date>\n";
		print XML "<starttime>$time</starttime>\n";
		print XML "<location>$locs{$loc}</starttime>\n";
		print XML "</screening>\n";
	};
};

for(keys%locs){
	print XML qq!<location id="$locs{$_}">
<longname>$_</longname>
</location>
!;
};

for(keys%secs){
	print XML qq!<section id="$secs{$_}">
<longname>$_</longname>
</section>
!;
};


print XML qq!</ffm>\n!;
close(XML);
