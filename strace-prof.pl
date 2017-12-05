#!/usr/bin/env perl

use strict;

# strace must have used the -ttt and -T options
# eg. strace -T -ttt -f ping -c1 google.com

# reads from STDIN


my ($startTime, $endTime) = ('','');
my ($wallClockTime,$totalCountedTime)=(0,0);

# determine if the first field is a PID
# this occurs if -f is used on strace
# ignoring PID at this time if so

my $pidChk=1;
my $shiftPid=0;

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

	#print "EndTime $endTime\n";

	my $elapsed = $a[$#a];
	$elapsed =~ s/[<>]//g;
	#print "elapsed: $elapsed\n";

	$totalCountedTime += $elapsed;
	
}

$wallClockTime = $endTime - $startTime;
my $unAccountedForTime = $wallClockTime - $totalCountedTime;

#printf "  Total Counted Time: $totalCountedTime\n";
#print "  Total Elapsed Time: $wallClockTime\n";
#print "Unaccounted for Time: $unAccountedForTime\n";

printf qq{
  Total Counted Time:   %9.2f
  Total Elapsed Time:   %9.2f
  Unaccounted for Time: %9.2f\n\n},
	, $totalCountedTime
	, $wallClockTime
	, $unAccountedForTime;


