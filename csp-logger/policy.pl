#!/usr/bin/perl -w

# Content-Security-Policy violation logger
# - https://developer.mozilla.org/en/Security/CSP/Using_CSP_violation_reports

use strict;
use JSON;
use Data::Dumper;

my $uid="sec";

$Data::Dumper::Indent = 1;

if($ENV{REQUEST_METHOD} ne "POST"){
	print "Status: 501 Method Not Implemented\n";
	failmail("CSP report requires POST, got: $ENV{REQUEST_METHOD}");
	print "Content-type: text/plain\n\n";
	print "CSP report requires POST\n";
	exit(0);
};

my $oreq;
while(<STDIN>){
	chomp;
	$oreq.=$_;
};
my $req=$oreq;

print "Content-type: text/plain\n\n";

my $report  = decode_json $req;

### Report success.
print "Thanks.\n";

open(M,"|/usr/sbin/sendmail -t") || die;
print M "From: $uid\n";
print M "To: $uid\n";
my $subj="CSP report";
if($report->{"csp-report"}->{request}){
	$report->{"csp-report"}->{request} =~ m!https?://([^/]+)!;
	my $host="$1";
	$subj.= " for $host";
};
print M "Subject: $subj\n";
print M "\n";
print M "UA=$ENV{HTTP_USER_AGENT}\n";
print M "IP=$ENV{REMOTE_ADDR} $ENV{REMOTE_PORT}\n";
print M "Ctt=$ENV{CONTENT_TYPE}\n" if($ENV{CONTENT_TYPE} ne "application/json");
print M "\n";
print M Data::Dumper->Dump([$report],['%report']);
#print M "\nEnv:\n"; print M map {"- $_: $ENV{$_}\n"} keys %ENV;
#print M "\nRequest:\n$req\n";
close(M);
exit(0);

sub failmail{
	open(M,"|/usr/sbin/sendmail -t 1>&2") || do {
		print STDERR "fopen failed: $!\n";
		die "Call sendmail: $!";
	};
	print M "From: $uid\n";
	print M "To: $uid\n";
	my $subj="CSP report failure";
	if($report->{"csp-report"}->{request}){
		$report->{"csp-report"}->{request} =~ m!https?://([^/]+)!;
		my $host="$1";
		$subj.= " for $host";
	};
	print M "Subject: $subj\n";
	print M "\n";
	print M "Error: @_\n\n";
	print M "UA=$ENV{HTTP_USER_AGENT}\n";
	print M "IP=$ENV{REMOTE_ADDR} $ENV{REMOTE_PORT}\n";
	print M "Ctt=$ENV{CONTENT_TYPE}\n" if($ENV{CONTENT_TYPE} && ($ENV{CONTENT_TYPE} ne "application/json"));
	print M "\nRequest:\n".($req) if($req);
#	print M "Env:\n"; print M map {"- $_: $ENV{$_}\n"} keys %ENV;
	close(M);
};
