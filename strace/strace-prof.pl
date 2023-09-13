#!/usr/bin/env perl

use strict;

# strace must have used the -ttt and -T options
# eg. strace -T [ -tt -ttt] -f ping -c1 google.com
# with -tt there is the possibility of error of the time rolls over past midnight
# reads from STDIN

my ($startTime, $endTime) = ('','');
my ($wallClockTime,$totalCountedTime)=(0,0);

# determine if the first field is a PID
# this occurs if -f is used on strace
# ignoring PID at this time if so

my $pidChk=1;
my $shiftPid=0;
my $timeFormat='';

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

	# determine if the time format ia hh:mm:ss.ffffff
	# or epoch.ffffff
	unless ( $timeFormat ) {
		if ( $a[0] =~ /[[:digit:]]{2}:[[:digit:]]{2}:[[:digit:]]{2}\.[[:digit:]]{6}/ ) { $timeFormat='ISO8601' }
		else { $timeFormat='epoch' }
	};

	if ( $timeFormat eq 'epoch') {
		$startTime = $a[0] unless $startTime;
		$endTime = $a[0];
	} else {
		#warn "Time Format: $timeFormat\n";
		$startTime = convtime($a[0]) unless $startTime;
		$endTime = convtime($a[0]);
		#warn "Start Time: $startTime\n";
		#warn "  End Time: $endTime\n";
	}


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

# convert a timestamp such as  08:38:16.809792 to seconds.fractional-seconds
sub convtime {
	my ($hours, $minutes, $seconds) = split(/:/,$_[0]);
	return ($hours * 3600) + ($minutes * 60) + $seconds;
}


