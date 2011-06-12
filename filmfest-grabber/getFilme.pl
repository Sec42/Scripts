#!/usr/local/bin/perl -s

# getFilme.pl
# - by Stefan `Sec` Zehl <sec@42.org>
# - Licence: BSD (3-clause)

use lib '../Scripts/GET/';

use Data::Dumper;
use warnings;
use strict;
use GET;
binmode(STDOUT,":utf8");

# Ignore "_parent" keys in HTML::Element dumping
$Data::Dumper::Sortkeys = sub {
	return [ (grep { $_ ne "_parent"} keys %{$_[0]}) ];
};


GET::config (
		min_cache => 3000,
		verbose => 1,
        );

my($body);

$body=GET::get_url("http://m.filmfest-muenchen.de/de/filmprogramm/uebersicht/film-abc.aspx?selector=%",
		html => 1);

for( $body->look_down( _tag => "li")){
	my($title,$link);
	print "* ";

	$title=$_->look_down( _tag => "a");
	print "Title: ",$title->content()->[0],"\n";

	$link=$title->attr("href");
	print "Link: $link\n";

	print "Otitle: ",$_->look_down( _tag => "p")->content()->[0],"\n";
	print "Image: ", $_->attr("style"),"\n";
	print "\n";

	my ($film,$img,$info,$cat,$txt,$screen);
	$film=GET::get_url("http://m.filmfest-muenchen.de${link}", html => 1);

	$img=$film->look_down ( class=> "m_filmDetailImage")->attr("src");
	print "* Image: $img\n";

	$info=$film->look_down ( class=> "m_filmDetailInfoLeft")->content();
	print "* Title1: ",$info->[0]->as_trimmed_text,"\n";
	print "* Title2: ",$info->[1]->as_trimmed_text,"\n";
	print "* Title3: ",$info->[2]->as_trimmed_text,"\n";
	print "* Title4: ",$info->[3]->as_trimmed_text,"\n";
	print "* Title5: ",$info->[4]->as_trimmed_text,"\n";
	print "* Title6: ",$info->[5]->as_trimmed_text,"\n";

	$cat=$film->look_down(class=> "m_filmDetailInfoLeft")->look_down(_tag=>"a");
	print "* Reihe: ",$cat->as_trimmed_text," : ",$cat->attr("href"),"\n";

	$txt=$film->look_down ( _tag => "td", colspan => "2");
	print "* Txt: ",$txt->content->[1]->as_HTML,"\n";


	$screen=$film->look_down ( _tag => "ul", class => "m_list m_noimage");

	for my $idx ($screen->look_down(_tag=>"li")){
		print "* When: ",($idx->content->[0]->content->[0]),"\n";
		print "* Where: ",($idx->content->[0]->content->[2]->as_trimmed_text),"\n";
	};





	exit(0);
};
