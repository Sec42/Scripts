#!/usr/local/bin/perl

package GET;

use strict;
use Module::Load;
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
		force_cache		=>	$ENV{FORCE_CACHE}?1:0, # 2: never get anything
		disable_charset	=>	0,
		verbose 		=>	0,
		cache_verbose	=>	0,
		sleep			=>	2,
		ratelimit		=>  "1/5",
		min_cache		=>	0,
		auth			=>	0,
		user			=>	"",
		pass			=>	"",
		html			=>	0,
		xml				=>	0,
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
	if($config{html}){
		load HTML::TreeBuilder;
	};
	if($config{xml}){
		load XML::LibXML;
	};
	cache_read unless(%cache || $config{disable_cachedb});
	$config{_done}=1;
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
	($config{_ratecnt},$config{_ratetime})=($config{ratelimit}=~m!(\d+)/(\d+)!);
};

sub check_url{
	croak "GET: no config?" unless($config{_done}); # Needs to be done before.

	my $url=shift;
	my $cachename = shift || mkcache($url);
	my $timestamp;

   	return undef if ($config{force_cache} && -f $cachename);
   	return undef if ($config{force_cache}>1);

	if(-f $cachename && !$config{disable_lastmod_guess}){
		$timestamp= (stat(_))[9];
	};
	if (-f $cachename && $config{min_cache}){
		$timestamp= $cache{$url}{time} || $timestamp;
		return undef if ($timestamp+$config{min_cache} > time);
	};

	my $ua = new LWP::UserAgent();
	$ua->agent($ua->_agent." etag/0.1");

	my $req = HTTP::Request->new( GET => $url );
	if(my $ucache=${cache{$url}}){
		print STDERR "GET: Cache exists\n" if $config{verbose}>1;

		if(defined $ucache->{'ETag'}){
			$req->header('If-None-Match' => $ucache->{'ETag'})
		};

		if(defined $ucache->{'Last-Modified'}){
#			$req->header('If-Modified-Since' => $ucache->{'Last-Modified'});
			$timestamp=0;
		};
	};
	if($config{auth}){
#print "Auth: $config{user} / $config{pass}\n";
		$req->authorization_basic($config{user},$config{pass});
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
	my $cnt=$cache{"count://".$req->uri->host}||0;
	my $ts=time;

	$ots=$ts if($ots>$ts); # Sanity fix.
	if($ots+$config{_ratetime}<$ts){
		$cache{"time://".$req->uri->host}=time;
		$cnt=0;
	};
	if(++$cnt > $config{_ratecnt}){
		my $sleep=$ots-$ts+$config{_ratetime};
		print STDERR "GET: ratelimit: sleeping ".($sleep)."s ...\n" 
			if ($config{verbose}>1 || $sleep > 60);
		sleep($sleep);
		$cnt=0;
		$cache{"time://".$req->uri->host}=time;
	}elsif($ts-$config{"time://global"} < $config{sleep}){
		print STDERR "GET: enforcing min_sleep ...\n" if $config{verbose}>1;
		sleep($config{sleep}-($ts-$config{"time://global"}));
	};
	$cache{"count://".$req->uri->host}=$cnt;
	$cache{"time://global"}=$ts;

#print $req->as_string();
	my $res = $ua->request($req);
#print $res->as_string();

	if ($res->is_success) {
		print STDERR "GET: Got new file.\n" if ($config{verbose});
		for (qw(ETag Last-Modified)){			# save ETag & Last-Modified
			$cache{$url}{$_}=$res->header($_) if
				defined $res->header($_);
		};
		$cache{$url}{time}=time;
		return $res->decoded_content($config{disable_charset}?(charset => "none"):());
	} elsif ( $res->code() eq '304' ) {
		print STDERR "GET: File not modified.\n" if $config{verbose};
		$cache{$url}{time}=time;
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
	local %config=%config; # Localize %config
	my $shortname=undef;

	if($#_ == 0){
		# Backwards compatible way to set cache file name.
		$shortname=shift;
	}else{
		config(@_) unless ($#_ == -1 && $config{_done} == 1);
	};

	my $timestamp=undef;
	my $content=undef;
	my $error=undef;
	$shortname||=mkcache($url); # Ensure we know where to cache

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

	my $cached=0;
	if (!defined $content){
		$cached=1;
		print "(cached)\n" if ($config{cache_verbose});
		open(CACHE,"<",$shortname) || do{
			if($config{force_cache}>1){
				return("",2) if wantarray;
				return "";
			};
			die "Cannot read cached URL: $!";
		};
		if ( !-f $shortname.".is_raw" && !$cache{$url}{is_raw}){
			binmode CACHE,":utf8" 
		};
		local $/;
		$content=<CACHE>;
		close CACHE;
	};

	if($config{html}){
		my $tree=HTML::TreeBuilder->new;
		$tree->parse($content);
		$tree->elementify();
		$content=$tree;
	};

	if($config{xml}){
		my $parser = XML::LibXML->new();
		my $doc = $parser->parse_string($content);
		$content=$doc;
	};

	if(wantarray){
		return ($content,$cached);
	}else{
		return $content;
	};
};

sub invalidate_url {
        my $url=shift;
        my $shortname=shift || mkcache($url);
        print STDERR "\nGET: Invalidating $shortname\n" if $config{verbose}>1;
        if ( -f $shortname ){
                unlink($shortname.".invalid") if (-f $shortname.".invalid");
                rename($shortname,$shortname.".invalid");
        };
        if(defined $cache{$url}){
                delete $cache{$url};
        }else{  
                print STDERR "\nGET: Trying to invalidate uncached $url\n";
        };
};      

sub mkcache {
	my $url=shift;
	$url=~s!^http://!!;
	$url=~s,/,!,g;

	$url= ($ENV{TMPDIR} || -d "/tmp" ? "/tmp" : ".")."/GET_".$url;
	
	return $url;
};

END {
	cache_write unless ($config{disable_cachedb} || !%cache);
};

1;
