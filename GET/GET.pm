#!/usr/local/bin/perl

package GET;

use strict;
use LWP::UserAgent;
use HTTP::Request;
use Data::Dumper;
use POSIX qw(strftime setlocale LC_TIME);

my $cache_file=".get_cache=$<"; # XXX

our $disable_auto_cacheDB=0;
our $disable_auto_cacheDB_maint=1;
our $disable_lastmod_guess=0;
our $skip_errors=0;
our $verbose=0;
our %cache;

sub verbose {
	$verbose=shift||($verbose+1);
};

sub cache_write {
	if(!$disable_auto_cacheDB_maint){
		print STDERR "GET: Cleaning cacheDB\n" if($verbose>1);
		die "not implemented yet!";
	};
	print STDERR "GET: Writing cacheDB\n" if($verbose>1);
	open(OUT,">",$cache_file) || die "Cannot write cacheDB file: $!";
	print OUT Data::Dumper->Dump([\%cache],[qw(*cache)]);
	close(OUT);
}

sub cache_read {
	if ( -f $cache_file ){
		print STDERR "GET: Reading cacheDB\n" if($verbose>1);
		do $cache_file;
	}else{
		print STDERR "GET: No cacheDB found\n" if($verbose);
		%cache=();
	};
};

sub check_url{
	my $url=shift;
	my $time = shift;

	cache_read unless(defined %cache || $disable_auto_cacheDB);

	my $ua = new LWP::UserAgent();
	$ua->agent($ua->_agent." etag/0.1");

	my $req = HTTP::Request->new( GET => $url );
	if(my $ucache=${cache{$url}}){
		print STDERR "GET: Cache exists\n" if $verbose>1;

		if(defined $ucache->{'ETag'}){
			$req->header('If-None-Match' => $ucache->{'ETag'})
		};

		if(defined $ucache->{'Last-Modified'}){
			$req->header('If-Modified-Since' => $ucache->{'Last-Modified'});
		};
	};
	if($time && !defined $req->header('If-Modified-Since')){
		print STDERR "GET: falling back on timestamp\n" if $verbose;
		my $loc= setlocale( LC_TIME);
		setlocale( LC_TIME, "C" );

		$req->header('If-Modified-Since' => 
				strftime('%a, %d %b %Y %H:%M:%S %Z',gmtime $time));
		setlocale( LC_TIME, $loc);
	};

	my $res = $ua->request($req);
	if ($res->is_success) {
		print STDERR "GET: Got new file.\n" if ($verbose);
		for (qw(ETag Last-Modified)){			# save ETag & Last-Modified
			$cache{$url}{$_}=$res->header($_) if
				defined $res->header($_);
		};
		return $res->decoded_content;
	} elsif ( $res->code() eq '304' ) {
		print STDERR "GET: File not modified.\n" if $verbose;
		return undef;
	} else {
		if($skip_errors){
			print STDERR "GET: skipping on error ",$res->status_line,"($url)\n";
			return undef;
		};
		print STDERR $res->status_line,"\n";
		die "Whoops, something went wrong\n";
	}
};

sub get_url {
	my $url=shift;
	my $shortname=shift || mkcache($url);
	my $timestamp=undef;

	print STDERR "\nGET: Processing $shortname\n" if $verbose>1;

	if(! -f $shortname && defined $cache{$url}){
		warn "GET: Cache file for $shortname was missing\n";
		delete $cache{$url};
	}elsif(-f _ && !$disable_lastmod_guess){
		$timestamp= (stat(_))[9];
	};
	my $content=check_url($url,$timestamp);

	if (defined $content){
		open(CACHE,">:utf8",$shortname) || die "Cannot cache URL: $!";
		print CACHE $content;
		close CACHE;
	}else{
		open(CACHE,"<:utf8",$shortname) || die "Cannot read cached URL: $!";
		local $/;
		$content=<CACHE>;
		close CACHE;
	};
	return $content;
};

sub mkcache {
	my $url=shift;
	$url=~s!^http://!!;
	$url=~s,/,!,;

	$url= ($ENV{TMPDIR} || -d "/tmp" ? "/tmp" : ".")."/GET_".$url;
	
	return $url;
};

END {
	cache_write unless ($disable_auto_cacheDB);
};

1;
