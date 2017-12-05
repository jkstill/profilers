#!/usr/bin/env perl

use strict;
use warnings;
use Data::Dumper;
use Getopt::Long;

my $cursorID;
my $sqlFragment;
my $help=0;

GetOptions (
	"cursor-id=s" => \$cursorID,
	"sql-fragment=s" => \$sqlFragment,
	"h|help!" => \$help
) or die usage(1);


if ($help) { usage(0); exit }

sub usage {

	my $exitVal = shift;
	use File::Basename;
	my $basename = basename($0);
	print qq{
    $basename

    usage: $basename - print execution stats per bind variable set from 10046 trace

    $basename --cursor-id --sql-fragment  --help

    --cursor-id ID of the cursor as seen in 10046 file

      example: the following cursor ID is 139665751367648

      PARSING IN CURSOR #139665751367648 len=34 dep=1 uid=104 oct=3 lid=104 tim=1561698984944 hv=1868446218 ad='7c5d6e00' sqlid='g4bamjjrpwfha'
      select c1 from ct where id = :n_id

    --sql-fragment  Some (or all) of the SQL statement being profiled

       This is necessary as the cursor ID's may get re-used.
       There is the possibility that not all instances of the SQL statement will be profiled
       A future enhancement may fix that.

example:

$basename --cursor-id 139665751367648 --sql-fragment 'select c1 from ct where id'

====== tim: 1561706686874 =========

Execution Statistics

         row count: 1
    optimizer goal: ALL_ROWS
      elapsed time: 0.000003
          cpu time: 0.000000
    physical reads: 0
   consistent gets: 4
      current gets: 0
 total logical IOs: 4


Bind Values
BIND#0=1

FETCH: FETCH #139665751367648:c=0,e=3,p=0,cr=4,cu=0,mis=0,r=1,dep=1,og=1,plh=3271862900,tim=1561706686925


====== tim: 1561706686816 =========
...

};

exit eval { defined($exitVal) ? $exitVal : 0 };
}




# this only works as long as the cursor# stays the same for a SQL

my ($searchForFetch,$gettingBinds,$exeFound,$sqlFound) = (0,0,0,0);

my $prevLine='';
my $line='';
my %hBinds=();
my $parseTime=0;
my $dummy;

my $debug=0;

while (<>) {

	chomp;

	$prevLine=$line;
	$line = $_;

	#print $line;

=head1 False Positives when matching SQL

 A SQL statement that is part of a PL/SQL block may appear twice.

 First in the PL/SQL block, and again later when the SQL is parsed and executed.

 This will cause non fatal errors when this script finds the SQL in the PL/SQL block.

 False Negatives may also occur.  Sometimes the SQL parse statement may not appear at all,
 such as when a 10046 trace has started after the SQL parse.

 Something like an --ignore-sql flag could deal with this,but would have its own issues

=cut


	# skip until our SQL found
	if ( ! $sqlFound ) {
		if ( $line =~ /^\Q$sqlFragment/ ) { $sqlFound = 1 }
		next;
	}

	# look for ^BINDS #140304068176776:
	if ( ! $gettingBinds ) {
		if ( $line =~ /^BINDS #${cursorID}/ ) {
			$gettingBinds = 1;
			# get the tim form the previous line, which should be a PARSE
			my @a=split(/,/,$prevLine);
			($dummy,$parseTime) = split(/=/,$a[10]);
			print "Parse Time: $parseTime\n" if $debug;

			next;
		}
	} else {
		if ( $line =~ /^\s+Bind#/ ) { print "$line : " if $debug}
		if ( $line =~ /^\s+value=/ ) { 
			my ($dummy,$value)=split(/=/,$line); 
			print "$value \n" if $debug;

			push @{$hBinds{$parseTime}->{BINDS}},$value;
		}
	}

	if ( $line =~ /^EXEC #${cursorID}/ ) {
		$gettingBinds = 0;
		$searchForFetch = 1;
		next;
	}

	if ($searchForFetch) {

		if ( $line =~ /^FETCH #${cursorID}/ ) {
			print "$line\n" if $debug;
			$hBinds{$parseTime}->{FETCH} = $line;	
			$searchForFetch = 0;
			next;
		}

	}

#print $line;
	
}

#print Dumper(\%hBinds);

my @optGoals = qw( ALL_ROWS FIRST_ROWS RULE CHOOSE );

foreach my $tim ( sort {$b <=> $a} keys %hBinds ) {

	# sample FETCH
	# FETCH #140304068176776:c=269959,e=725736,p=59,cr=40022,cu=0,mis=0,r=0,dep=0,og=1,plh=1619557942,tim=1510368246997484

	my @a=split(/,/,$hBinds{$tim}->{FETCH});

#print 'FETCH Dump: ', Dumper(\@a);

	my $cpuTime = sprintf("%7.6f", (split(/=/,$a[0]))[1] / 10**6 );
	my $elapsedTime = sprintf("%7.6f", (split(/=/,$a[1]))[1] / 10**6);;
	my $physReads = (split(/=/,$a[2]))[1];
	my $consistentGets = (split(/=/,$a[3]))[1];
	my $currentGets = (split(/=/,$a[4]))[1];
	my $rowCount = (split(/=/,$a[6]))[1];

	my $logicalIOs = $currentGets + $consistentGets;

	my $optGoalNum = (split(/=/,$a[8]))[1];

	my $optGoal='UNKNOWN';


	print qq {

====== tim: $tim =========

Execution Statistics

         row count: $rowCount
    optimizer goal: $optGoals[$optGoalNum-1]
      elapsed time: $elapsedTime
          cpu time: $cpuTime
    physical reads: $physReads
   consistent gets: $consistentGets
      current gets: $currentGets
 total logical IOs: $logicalIOs


};

	print "Bind Values\n";

	my $bc=0;
	my @b = map { 'BIND#' . $bc++ . '=' . $_ } @{$hBinds{$tim}->{BINDS}};
	print join("\n",@b), "\n";

	print "\nFETCH: $hBinds{$tim}->{FETCH}\n";



}

