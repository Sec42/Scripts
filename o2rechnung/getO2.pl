#!/usr/bin/perl

# getO2.pl - Script to fetch your bill (PDF) and traffic.CSV for
# O2 (germany) customers.

use strict;
use utf8;
use WWW::Mechanize;

use constant DEBUG =>1;

umask(0077);

my($phone,$pass,$pin)|
open (F,"<","credentials.ini")|| die "Can't read credentials: $!\n";
while(<F>){
	chomp;
	/^phone=(.*)/ && do {$phone=$1;next};
	/^pass=(.*)/  && do {$pass= $1;next};
	/^pin=(.*)/   && do {$pin=  $1;next};
	warn "Don't understand line $_\n";
};
die "Some credentials missing." unless ($phone && $pass && $pin);
close(F);

my $url;
$url="https://login.o2online.de/loginRegistration/loginAction.do?_flowId=login";

my $mech = WWW::Mechanize->new(autocheck => 1);

$mech->get( $url );

if(DEBUG) {
	open(F,">1.html"); print F $mech->content();
};


$mech->submit_form(
		form_name => "login",
		fields      => {
			loginName => $phone,
			password => $pass,
		},
		button => "_eventId_login"
);

if(DEBUG) {
	open(F,">2.html"); print F $mech->content();
}

#$mech->follow_link( text_regex => qr/Weiter/i );
$mech->submit_form( form_number => 1);

if(DEBUG) {
	open(F,">3.html"); print F $mech->content();
}

$mech->follow_link( text_regex => qr/Mein O2/i );

#$mech->submit_form( form_number => 1);

if(DEBUG) {
	open(F,">:utf8","4.html"); print F $mech->content();
};

	my $rech=$mech->find_link(text_regex => qr!Rechnung.*PDF!s);
	if (!defined $rech){
		die "No PDF link found!";
	};

	my $lnk=$mech->find_link(text_regex => qr!CSV!);
	if (!defined $lnk){
		die "No CSV link found!";
	};
	$lnk=$lnk->url(); $lnk=~s!.*/!!; $lnk=~y/a-zA-Z0-9._-//cd;

$mech->follow_link( text_regex => qr!CSV! ); 

if(DEBUG){
	open(F,">5.html"); print F $mech->content();
};

$mech->submit_form(
		form_name => "form2",
		fields      => {
			PKK => $pin,
		},
);

open(F,">:utf8",$lnk); print F $mech->content();

$mech->get( $rech->url() );

	$rech=$rech->url(); $rech=~s!.*/!!; $rech=~y/a-zA-Z0-9._-//cd;

open(F,">:utf8",$rech); print F $mech->content();

print "Fetched:\n\n";
system ("ls -l '$lnk' '$rech'");
