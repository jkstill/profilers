#!/usr/bin/perl -w

# Jared Still - Pythian
# 2013-02-03
# still@pythian.com
# jkstill@gmail.com


=head1 sprof.pl

 Given a Linux strace file generated with the -T and -tt options,
 aggregate the time per system call.

 Also show elapsed time, syscall time and unaccounted for time

 > ../../../bin/sprof.pl -file t.trc
 === gettimeofday ===
   count: 2
   time : 0.000023
 === lseek ===
   count: 5
   time : 0.000061
 === poll ===
   count: 3
   time : 0.000039
 === write ===
   count: 8
   time : 0.000563

 Elapsed Seconds: 0.060164
 SyscallTime    : 0.000686
 Unaccounted For: 0.059478

 Unaccounted For Time: 10046 overhead, strace overhead, db time

=cut


use warnings;
use strict;
use Data::Dumper;
use Getopt::Long;


my %optctl = ();
my ($traceFile, $getHelp, $csvOutput);
my $debug=0;

GetOptions(\%optctl,
	"file=s" => \$traceFile,
	"csv!" => \$csvOutput,
	"help" => \$getHelp,
	"debug!"
);

usage(0) if $getHelp;
usage(1) unless $traceFile;

open (my $fh, '<', $traceFile) || die usage(2);

my %syscalls;
my ($line,$totalSyscallTime);
# simple timestamp call - will fail if it crosses midnight
my ($startTimeStamp, $endTimeStamp);
my ($startTime, $endTime);

while (<$fh>){
	chomp;
	$line = $_;

	next if $line =~ /^.*?\?$/;  # last line in file mayb be 'exit_group(0)     = ?'
	next if $line =~ /\+\+\+ exit/;

	$line =~ /
		([\d]+?)\s+ # PID
		([\d]{2}:[\d]{2}:[\d]{2}\.[\d]{6})\s+ # timestamp
		(\w+?)\( # syscall
		(.+?)\)\s+=\s+ # contents
		([\d]+)\s+ # results
		(\(Timeout\))?\s*<([\d\.]+)> # timing
	/x; 

	my ($pid,$timestamp,$syscall,$contents,$results,$timeout,$timing) = ($1,$2,$3,$4,$5,$6,$7);
	$timeout = defined($timeout) ? $timeout : '';

print qq{
	pid:       $pid
	timestamp: $timestamp
	syscall:   $syscall
	contents:  $contents
	results:   $results
	timeout:   $timeout
	timing:    $timing
} if $debug;


	if ($. == 1 ) { # first line
		$startTimeStamp = $timestamp;
	} else {
		$endTimeStamp = $timestamp;
	}
	

	#last if $. > 10;
	#print "$syscall \n";

	$totalSyscallTime += $timing;
	$syscalls{$syscall}->{timing} += $timing;
	$syscalls{$syscall}->{count}++;
}

# calc elapsed time

$startTimeStamp =~ /([\d]{2}):([\d]{2}):([\d]{2}\.[\d]{6})/;
my $startSeconds = ($1*3600) + ($2*60) + $3;

$endTimeStamp =~ /([\d]{2}):([\d]{2}):([\d]{2}\.[\d]{6})/;
my $endSeconds = ($1*3600) + ($2*60) + $3;

my $elapsedSeconds = $endSeconds - $startSeconds;

print "syscall,count,timing\n" if $csvOutput;

my $syscallElapsedTime;
foreach my $syscall ( sort keys %syscalls ) {
	$syscallElapsedTime += $syscalls{$syscall}->{timing};

	if ($csvOutput) {
		printf ("%s,%d,%5.6f\n", $syscall,$syscalls{$syscall}->{count}, $syscalls{$syscall}->{timing});
	} else {
		print "=== $syscall === \n";
		printf ("   count: %d\n", $syscalls{$syscall}->{count});
		printf ("   time : %5.6f\n", $syscalls{$syscall}->{timing});
	}
}

my $unaccontedForTime = $elapsedSeconds - $syscallElapsedTime;

if ($csvOutput) {
	printf("Elapsed Seconds,1,%5.6f\n", $elapsedSeconds);
	printf("SyscallTime,1,%5.6f\n", $syscallElapsedTime);
	printf("Unaccounted For,1,%5.6f\n", $unaccontedForTime);
} else {
	printf("\n\nElapsed Seconds: %5.6f\n", $elapsedSeconds);
	printf(    "SyscallTime    : %5.6f\n", $syscallElapsedTime);
	printf(    "Unaccounted For: %5.6f\n", $unaccontedForTime);
	print"\nUnaccounted For Time: 10046 overhead, strace overhead, db time\n";
}

#print Dumper(\%syscalls);

sub usage {

	my $exitVal = shift;
	use File::Basename;
	my $basename = basename($0);
	print qq{
$basename

usage: $basename - show aggregate call per syscal in an strace file

must have used -T -tt with strace

$basename -file strace-file-name

   -help
   -file <strace file name>
   -csv  format output as csv

examples here:

   $basename -file strace-23438.trc
};

exit eval { defined($exitVal) ? $exitVal : 0 };
}




