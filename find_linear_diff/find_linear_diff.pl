#!/usr/local/bin/perl -s

# find_linear_diff.pl - Tries to reconstruct the history of a file
#   by finding a minimal set of diffs from one version to the next.
#
# - by Stefan `Sec` Zehl <sec@42.org>
# - Licence: BSD (2-clause)
#
# Usage: find_linear_diff [-v] <list of filenames>
#
# -v -- Verbose
# -s -- Creates sample script with git commits.

use strict;
use warnings;
use autodie;
use constant DEBUG => 0;

our($v,$s);

use Algorithm::Diff qw(sdiff);

my %files=map {$_ => 1}@ARGV;
my %data;

print "Reading files ...\n" if($v);
for my $file (keys %files){
	open(my $f,"<",$file);

	$data{$file}=[<$f>];
	printf "%-20s:%4d lines\n",$file,$#{$data{$file}} if($v);
	close($f);
};


my $first=$ARGV[0];
delete $files{$first};
print "First: $first\n" if(DEBUG);

my($left,$right);
$left=$first;$right=$first;
my(@files)=($right);

while(keys %files){
	print "\nEnter: $left / $right\n" if(DEBUG);
	my($leftmin,$rightmin)=(9e9,9e9);
	my($leftfile,$rightfile);
	my($len);
	for my $second (keys %files){

		$len = diffcnt($second,$left);
		if($len<$leftmin){
			$leftmin=$len;
			$leftfile=$second;
		}

		$len = diffcnt($right,$second);
		if($len<$rightmin){
			$rightmin=$len;
			$rightfile=$second;
		}
	};

	print "l:$leftmin [$leftfile], r: $rightmin [$rightfile]\n" if(DEBUG);
	if($leftmin<$rightmin){
		$left=$leftfile;
		delete $files{$left};
		unshift @files,"<$leftmin>";
		unshift @files,$left;
		print  "Pick[l]: $left\n" if (DEBUG);
	}else{
		$right=$rightfile;
		delete $files{$right};
		push @files,"<$rightmin>";
		push @files,$right;
		print  "Pick[r]: $right\n" if (DEBUG);
	};

	print "L: @files\n" if (DEBUG);
};

print "The list:\n. ";
for (@files){
	if(/<(\d+)>/){
		printf "\n` <%03d> ",$1;
		next;
	};
	print ;
};
print "\n";

if($s){
	open(F,">","dwim-commit.sh");
	my $diff;
	my $msg;
	my $version=0;
	my $prev;
	print "\n";
	print F "# Shell script start\n";
	print F "file=NAME_HERE\n";
	for (@files){
		if(/</){ # A bit hacky %-)
			$diff=$_;
			next;
		};
		$version++;
		print F "\n";
		print F ("#"x32)." Version $version ".("#"x32)."\n";
		print F "cp $_ \$file\n";
		if ($version == 1){
			print F "git add \$file\n";
			$msg="Created: ".  scalar localtime ((stat($_))[9]) ."\n".
				"\nInitial checkin\n";
		}else{
			if(1){
				print F scalar minidiff($prev,$_,"# ");
			};
			$msg="Created: ".  scalar localtime ((stat($_))[9]) . "\n".
			"Diffcount: $diff\n";
		};
		print F qq!git commit -m "$msg" \$file\n!;
		$prev=$_;
	};
	print F "# Shell script end\n";
	close(F);
};

sub diffcnt{
	my $diff=sdiff( $data{$_[0]}, $data{$_[1]} );
	my $ctr=0;
	for my $e (@{$diff}){
		next if $e->[0] eq "u";
		$ctr++;
		$ctr++ if ($e->[0] eq "-"); # Deletions are less likely
	};
	return $ctr;
};

sub minidiff{
	my $prefix=$_[2]||"";
	my $diff=sdiff( $data{$_[0]}, $data{$_[1]} );
	my $return;
	for my $e (@{$diff}){
		next if $e->[0] eq "u";
		if($e->[0] ne "+"){
			$return.=$prefix.$e->[0]." ".$e->[1];
		};
		if($e->[0] ne "-"){
			$return.=$prefix.$e->[0]." ".$e->[2];
		};
	};
	return $return;
};
