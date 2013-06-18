#!/usr/bin/perl -w

# Simple Content-Security-Policy violation logger

# Firefox header "X-Content-Security-Policy":
# - https://people.mozilla.com/~bsterne/content-security-policy/details.html
# supports only old-style "; options inline-script eval-script"
#
# Chrome header "Content-Security-Policy":
# - http://www.w3.org/TR/CSP11/
# supports new "'unsafe-inline' 'unsafe-eval'"

use strict;
use JSON;
use Data::Dumper;

my $uid="sec"; # Config this


if($ENV{REQUEST_METHOD} ne "POST"){
	print "Status: 405 Method Not Allowed\n";
	domail("CSP report failure", "CSP report requires POST, got: $ENV{REQUEST_METHOD}");
	print "Content-type: text/plain\n\n";
	print "CSP report requires POST\n";
	exit(0);
};

my $req;
while(<STDIN>){
	chomp;
	$req.=$_;
};

if($ENV{CONTENT_TYPE} ne "application/json"){
	print "Status: 415 Unsupported Media Type\n";
	domail("CSP content failure", 
			"CSP report requires application/json, got: $ENV{CONTENT_TYPE}",
			"req: $req");
	print "Content-type: text/plain\n\n";
	print "CSP report requires application/json\n";
	exit(0);
};

my $report  = decode_json $req;

if (!defined $report){
	print "Status: 422 Unprocessable Entity\n";
	domail("CSP parsing failue",
			"JSON decoding failed",
			"Req: $req\n"
			);
	print "Content-type: text/plain\n\n";
	print "could not parse JSON data\n";
	exit(0);
};


### Report success.
print "Content-type: text/plain\n\n";
print "Thanks.\n";

$Data::Dumper::Indent = 1;
domail("CSP report", Data::Dumper->Dump([$report],['report']) );

exit(0);


### Send a mail.
sub domail {
	my $subj=shift||"No subject";

	if(defined $report){
		my $uri=$report->{"csp-report"}->{"document-uri"} // $report->{"csp-report"}->{request};
		if (defined $uri && $uri =~ m!https?://([^/]+)!){
			$subj.=" for $1";
		};
	};
	open(M,"|/usr/sbin/sendmail -t 1>&2") || do {
		print STDERR "fopen failed: $!\n";
		die "Call sendmail: $!";
	};
	print M "From: $uid\n";
	print M "To: $uid\n";
	print M "Subject: $subj\n";
	print M "\n";
	print M "UA=$ENV{HTTP_USER_AGENT}\n";
	print M "IP=$ENV{REMOTE_ADDR} $ENV{REMOTE_PORT}\n";
	print M "Ctt=$ENV{CONTENT_TYPE}\n" if($ENV{CONTENT_TYPE} && ($ENV{CONTENT_TYPE} ne "application/json"));
	print M "\n";
	print M join("\n",@_);
	print M "\n";
#	print M "Env:\n"; print M map {"- $_: $ENV{$_}\n"} keys %ENV;
	close(M);
};

