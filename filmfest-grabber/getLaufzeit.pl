#!/usr/bin/perl

use strict;
use utf8;
use WWW::Mechanize;

my $url="http://www.filmfest-muenchen.de/de/filmprogramm/timetable.aspx";

my $mech = WWW::Mechanize->new(autocheck => 1);

$mech->get( $url );

$mech->form_number( 2);
my $cats=$mech->current_form()->find_input("programmReihe");

for my $inp (@{$cats->{menu}}){
	print "Doing: ",$inp->{name},"\n";

	$mech->form_number( 2);
	my $cats=$mech->current_form()->find_input("programmReihe");
	$mech->set_fields("programmReihe",$inp->{value});
	$mech->click( "Anzeigen2" );

	open(F,">:utf8",$inp->{value}.".html"); print F $mech->content();close(F);

	$mech->back;
};
