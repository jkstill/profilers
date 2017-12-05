#!/usr/bin/env perl

use strict;
use warnings;
use Data::Dumper;
use Getopt::Long;


my $useHistograms=0;

GetOptions (
	"histograms!" => \$useHistograms
) or die usage(1);

#die "using histograms \n" if $useHistograms;

# strace must have used the -ttt and -T options
# eg. strace -T -ttt -f ping -c1 google.com
# reads from STDIN

my ($startTime, $endTime) = ('','');
my ($wallClockTime,$totalCountedTime)=(0,0);

use constant COUNT_IDX => 0;
use constant ELAPSED_IDX => 1;
use constant MIN_IDX => 2;
use constant MAX_IDX => 3;

=head %calls

$calls { callName => [ count, elapsed, min, max ] }

=cut

my %calls=();

# determine if the first field is a PID
# this occurs if -f is used on strace
# ignoring PID at this time if so

my $pidChk=1;
my $shiftPid=0;

my %histograms=();

while (<>) {

	#print;
	chomp;
	next unless /.*>$/;

	my @a=split(/\s+/);

	if ($pidChk) { 
		$pidChk=0;
		$shiftPid = 1 if $a[0] =~ /^[[:digit:]]{1,7}$/;
		#print "Shifting PID\n" if $shiftPid;
	}

	shift @a if $shiftPid;

	$startTime = $a[0] unless $startTime;
	$endTime = $a[0];

	my $syscall = $a[1];

	my $parenPos = index($syscall,'(');

	if ($parenPos > 0) {
		$syscall = substr($syscall,0,$parenPos);
	}

	#print "syscall: $syscall\n";

	my $elapsed = $a[$#a];
	$elapsed =~ s/[<>]//g;
	#print "elapsed: $elapsed\n";

	$calls{$syscall}[COUNT_IDX]++;
	$calls{$syscall}[ELAPSED_IDX] += $elapsed;

	if ( defined( $calls{$syscall}[MIN_IDX] )) {
		if ( $elapsed < $calls{$syscall}[MIN_IDX] ) { $calls{$syscall}[MIN_IDX] = $elapsed }
	} else {
		$calls{$syscall}[MIN_IDX] = $elapsed ;
	}

	if ( defined( $calls{$syscall}[MAX_IDX] )) {
		if ( $elapsed > $calls{$syscall}[MAX_IDX] ) { $calls{$syscall}[MAX_IDX] = $elapsed }
	} else {
		$calls{$syscall}[MAX_IDX] = $elapsed ;
	}

	push @{$histograms{$syscall}} , $elapsed if $useHistograms;

	$totalCountedTime += $elapsed;
	
}

$wallClockTime = $endTime - $startTime;
my $unAccountedForTime = $wallClockTime - $totalCountedTime;

#printf "  Total Counted Time: $totalCountedTime\n";
#print "  Total Elapsed Time: $wallClockTime\n";
#print "Unaccounted for Time: $unAccountedForTime\n";

printf qq{
  Total Counted Time:   %9.8f
  Total Elapsed Time:   %9.8f
  Unaccounted for Time: %9.8f\n\n},
	, $totalCountedTime
	, $wallClockTime
	, $unAccountedForTime;


printf "      %20s %11s      %11s        %11s     %11s     %11s\n", 'Call',  'Count', 'Elapsed', 'Min', 'Max', 'Avg ms';


foreach my $syscall ( sort { $calls{$a}[1] <=> $calls{$b}[1] } keys %calls ) {

	printf "      %20s   %9d   %16.6f   %14.6f  %14.6f  %14.6f\n"
		, $syscall
		, $calls{$syscall}[COUNT_IDX]
		, $calls{$syscall}[ELAPSED_IDX]
		, $calls{$syscall}[MIN_IDX]
		, $calls{$syscall}[MAX_IDX]
		, $calls{$syscall}[ELAPSED_IDX] > 0 ? ($calls{$syscall}[ELAPSED_IDX] / $calls{$syscall}[COUNT_IDX]) * 1000 : 0; # avg

}


#print Dumper(\%histograms);

if ($useHistograms) {
	# use the index from the main data
	foreach my $syscall ( sort { $calls{$a}[1] <=> $calls{$b}[1] } keys %calls ) {
		#print "Syscall: $syscall\n\t";
		#print "Count: " , $#{$histograms{$syscall}} + 1 , "\n";
		processHistBucket($calls{$syscall}[MIN_IDX], $calls{$syscall}[MAX_IDX], @{$histograms{$syscall}});
	}
}


sub getHistBucketCount {
	my( $minVal, $maxVal, $count) = @_;

	# need at least 5 values for histogram
	if ($count < 5) { return 1 }
	else {
		return 5;
	}

}

sub processHistBucket {
	my $minVal = shift;
	my $maxVal = shift;
	my @ary = @_;

	#my @ary = @{$aryRef};

	my $bucketCount = getHistBucketCount($minVal, $maxVal, $#ary);

	#print "bucketCount: $bucketCount\n";
	#

	# WIP
	# foreach my $bucket in ( 
	
}

