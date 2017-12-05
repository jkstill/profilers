#!/usr/bin/env perl

use strict;
use warnings;
use Data::Dumper;


# strace must have used the -ttt and -T options
# eg. strace -T -ttt -f ping -c1 google.com
# reads from STDIN

my ($startTime, $endTime) = ('','');
my ($wallClockTime,$totalCountedTime)=(0,0);

=head %calls

$calls { callName => [ count, elapsed ] }

=cut

my %calls=();

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

	my $syscall = $a[1];

	my $parenPos = index($syscall,'(');

	if ($parenPos > 0) {
		$syscall = substr($syscall,0,$parenPos);
	}

	#print "syscall: $syscall\n";

	my $elapsed = $a[$#a];
	$elapsed =~ s/[<>]//g;
	#print "elapsed: $elapsed\n";

	$calls{$syscall}[0]++;
	$calls{$syscall}[1] += $elapsed;

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


printf "      %20s %11s      %11s        %11s\n", 'Call',  'Count', 'Elapsed', 'Avg ms';


foreach my $syscall ( sort { $calls{$a}[1] <=> $calls{$b}[1] } keys %calls ) {

	printf "      %20s   %9d   %14.6f   %16.8f\n", $syscall, $calls{$syscall}[0], $calls{$syscall}[1], $calls{$syscall}[1] > 0 ? ($calls{$syscall}[1] / $calls{$syscall}[0]) * 1000 : 0;

}

