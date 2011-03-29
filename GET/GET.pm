#!/usr/local/bin/perl

package GET;

use strict;
use LWP::UserAgent;
use HTTP::Request;
use Data::Dumper;
use POSIX qw(strftime setlocale LC_TIME);
use Encode qw(is_utf8);
use Carp;

my $cache_file=".get_cache=$<"; # XXX

$|=1;

our %cache;
our %config=(
		disable_cachedb =>	0,
		disable_cachedb_automaint => 1, # Not yet implemented
		disable_lastmod_guess	=>	0,
		skip_errors		=>	0,
		force_cache		=>	$ENV{FORCE_CACHE}?1:0,
		disable_charset	=>	0,
		verbose 		=>	0,
		cache_verbose	=>	0,
		sleep			=>	5,
);

sub cache_read;

sub config {
	my $arg;

	while ($arg=shift){
		croak "GET: odd number of arguments" if scalar @_ ==0;
#		next if !defined $arg;

		# Sanitize arguments a bit:
		$arg=lc $arg;$arg=~y/-/_/;$arg=~s/^-+//;

		if (defined $config{$arg}){
			$config{$arg}=shift;
		}else{
			carp "GET: unknown option $arg used";
		};
	};
	cache_read unless(defined %cache || $config{disable_cachedb});
};

sub cache_write {
	if(!$config{disable_cachedb_automaint}){
		print STDERR "GET: Cleaning cacheDB\n" if($config{verbose}>1);
		die "not implemented yet!";
	};
	print STDERR "GET: Writing cacheDB\n" if($config{verbose}>1);
	open(OUT,">",$cache_file) || die "Cannot write cacheDB file: $!";
	print OUT Data::Dumper->Dump([\%cache],[qw(*cache)]);
	close(OUT);
}

sub cache_read {
	if ( -f $cache_file ){
		print STDERR "GET: Reading cacheDB\n" if($config{verbose}>1);
		do $cache_file;
	}else{
		print STDERR "GET: No cacheDB found\n" if($config{verbose});
		%cache=();
	};
};

sub check_url{
	my $url=shift;
	my $cachename = shift || mkcache($url);
	my $timestamp;

   	return undef if ($config{force_cache} && -f $cachename);

	if(-f $cachename && !$config{disable_lastmod_guess}){
		$timestamp= (stat(_))[9];
	};

	cache_read unless(defined %cache || $config{disable_cachedb});

	my $ua = new LWP::UserAgent();
	$ua->agent($ua->_agent." etag/0.1");

	my $req = HTTP::Request->new( GET => $url );
	if(my $ucache=${cache{$url}}){
		print STDERR "GET: Cache exists\n" if $config{verbose}>1;

		if(defined $ucache->{'ETag'}){
			$req->header('If-None-Match' => $ucache->{'ETag'})
		};

		if(defined $ucache->{'Last-Modified'}){
			$req->header('If-Modified-Since' => $ucache->{'Last-Modified'});
		};
	};
	if($timestamp && !defined $req->header('If-Modified-Since')){
		print STDERR "GET: falling back on timestamp\n" if $config{verbose};
		my $loc= setlocale( LC_TIME);
		setlocale( LC_TIME, "C" );

		$req->header('If-Modified-Since' => 
				strftime('%a, %d %b %Y %H:%M:%S %Z',gmtime $timestamp));
		setlocale( LC_TIME, $loc);
	};

#	print "Server: ",$req->uri->host,"\n";

	my $ots=$cache{"time://".$req->uri->host}||0;
	my $ts=time;
	$ots=$ts if($ots>$ts);
	if ($ots+$config{sleep}>$ts){
		print STDERR "GET: sleeping ".($ots-$ts+$config{sleep})."s ...\n" if $config{verbose}>1;
		sleep($ots-$ts+$config{sleep});
	};

	my $res = $ua->request($req);

	$cache{"time://".$req->uri->host}=time;

	if ($res->is_success) {
		print STDERR "GET: Got new file.\n" if ($config{verbose});
		for (qw(ETag Last-Modified)){			# save ETag & Last-Modified
			$cache{$url}{$_}=$res->header($_) if
				defined $res->header($_);
		};
		return $res->decoded_content($config{disable_charset}?(charset => "none"):());
	} elsif ( $res->code() eq '304' ) {
		print STDERR "GET: File not modified.\n" if $config{verbose};
		return undef;
	} else {
		if(wantarray){
			return (undef,$res->status_line);
		};
		if($config{skip_errors}){
			print STDERR "GET: skipping on error ",$res->status_line,"\n";
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
	my $content=undef;
	my $error=undef;

	print STDERR "\nGET: Processing $shortname\n" if $config{verbose}>1;

	if(! -f $shortname && defined $cache{$url}){
		warn "GET: Cache file for $shortname was missing\n";
		delete $cache{$url};
	};

	($content,$error)=check_url($url,$shortname);

	if (defined $content){
		open(CACHE,">",$shortname) || die "Cannot cache URL: $!";
		if(!is_utf8($content)){
			print STDERR "GET: I think its raw\n" if $config{verbose}>1;
			if($config{disable_cachedb}){
				open(X,">",$shortname.".is_raw");
				close(X);
			}else{
				$cache{$url}{is_raw}=1;
			};
		}else{
			binmode CACHE,":utf8";
			unlink($shortname.".is_raw");
			$cache{$url}{is_raw}=0;
		};
		print CACHE $content;
		close CACHE;
	}elsif(defined $error){
		if($config{skip_errors}){
			if ( -f $shortname){
				; # get from cache
			}else{
				$content="";
			};
		}elsif(wantarray){
			return(undef,$error);
		}else{
			die "Whoops, something went wrong: $error\n";
		};
	};

	if (!defined $content){
		print "(cached)" if ($config{cache_verbose});
		open(CACHE,"<",$shortname) || die "Cannot read cached URL: $!";
		if ( !-f $shortname.".is_raw" && !$cache{$url}{is_raw}){
			binmode CACHE,":utf8" 
		};
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
	cache_write unless ($config{disable_cachedb} || !defined %cache);
};

1;
