#!/usr/bin/env perl

use strict;
use warnings;
use Data::Dumper;

# strace must have used the -ttt and -T options
# eg. strace -T [ -tt -ttt] -f ping -c1 google.com
# with -tt there is the possibility of error of the time rolls over past midnight
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

my $timeFormat='';

while (<>) {

	#print;
	chomp;
	next if /unfinished/;
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

	my $syscall = $a[1];

	my $parenPos = index($syscall,'(');

	if ($parenPos > 0) {
		$syscall = substr($syscall,0,$parenPos);
	}

	#print "syscall: $syscall\n";

	my $elapsed = $a[$#a];
	$elapsed =~ s/[<>]//g;
	#print join(' - ', @a),"\n";
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


# convert a timestamp such as  08:38:16.809792 to seconds.fractional-seconds
sub convtime {
	my ($hours, $minutes, $seconds) = split(/:/,$_[0]);
	return ($hours * 3600) + ($minutes * 60) + $seconds;
}



