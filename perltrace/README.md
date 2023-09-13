Applying External Timing Data To Untimed Events
===============================================
                    
Or how to have an answer other than “I don’t know” when asked “How long does that take?”.

Recently while working on a client site I discovered that it takes 30-90 seconds to make an ssh connection to one of the servers. Connections between servers for this client typically take < 1 second, so the lengthy connection time was definitely out of order.

If you are familiar with debugging ssh connections you are probably familiar with the ‘-v’ option that directs ssh to output verbose comments stating which operation is currently taking place.  You can add up to three -v options on the command line, increasing the verbosity with each one.  An example follows:

A normal ssh connection

``text
16:20:jkstill-22 > ssh 192.168.1.132
Last login: Wed Jul 13 16:20:53 2011 from poirot.jks.com
[ /home/jkstill ] $
```

Connect with a single -v command line options

```text
16:21:jkstill-22 > ssh -v 192.168.1.132
OpenSSH_5.2p1, OpenSSL 0.9.7g 11 Apr 2005
debug1: Reading configuration data /usr/local/etc/ssh_config
debug1: Connecting to 192.168.1.132 [192.168.1.132] port 22.
debug1: Connection established.
debug1: identity file /home/jkstill/.ssh/identity type -1
...
debug1: Authentication succeeded (publickey).
debug1: channel 0: new [client-session]
debug1: Entering interactive session.
Last login: Wed Jul 13 16:21:00 2011 from poirot.jks.com
```

Now connect with three -v command line options

```text
16:22:jkstill-22 > ssh -v -v -v 192.168.1.132
OpenSSH_5.2p1, OpenSSL 0.9.7g 11 Apr 2005
debug1: Reading configuration data /usr/local/etc/ssh_config
debug2: ssh_connect: needpriv 0
debug1: Connecting to 192.168.1.132 [192.168.1.132] port 22.
debug1: Connection established.
debug1: identity file /home/jkstill/.ssh/identity type -1
debug3: Not a RSA1 key file /home/jkstill/.ssh/id_rsa.
debug2: key_type_from_name: unknown key type '-----BEGIN'
debug3: key_read: missing keytype
```

So, now I can connect to the remote server, observe the screen and see which operations of the connection are taking a long time.

There are however at least two problems with this:

- I don’t know how long each bit is taking
- Even though I can see it is slow, there’s no way easy for me to pass this information along.

If only ssh provided some method for showing the timing of each operation. Then I could create a log file of it, bundle it up into a zip file and send it to the system administrator with an explanation of the problem, and corroborating data show where ssh was having problems.

As this was a linux system, I could have just used strace. Strace is too granular for this purpose – it provided far more data than I wanted.

And like it or not, sometimes I am not working on my favorite OS.  Sometimes I work on Windows, and it would be nice to have some method of obtaining timing data that would work on many platforms.

About this time I had an idea. They don’t occur all that often, so I was glad to have one to entertain.

The diagnostic output from most programs is usually unbuffered, that is, it is written directly to standard output or error output as soon as it occurs.  If that is the case, then the time between each line of output is the amount of time the operation required to run.

Ah hah!  Why don’t I just collect the time between each line, and report the difference?

Doing so would allow me to see which parts of ssh are taking so much time.

Being something of a Perl aficionado  I set about creating a utility to accept text into standard output, and report the time difference separating the arrival of each line.

While it did not turn in to a daunting task, if you’re at all familiar with Oracle 10046 trace files you will have some knowledge of the difficulty of timing events. It is not always straight forward. For instance, sometimes the timing for the event appears before the event itself appears in the output.

To keep this simple, useful and maintainable, the following goals were set for this new utility:

- it should be able to track timing regardless of whether the diagnostic output appears before or after the actual operation
- the timing should be reasonably close to reality – small differences (overhead in the trace program) are OK
- not getting the timing right in the first line fed to the utility is OK – the startup time of the trace utility will affect it

Thus perltrace.pl was born (known as perltrace in the rest of this article)

Perltrace is meant to be used in a pipeline. Rather than trace an ssh operation, I used perltrace to get timing data for an scp operation. The reason for doing so is that the ssh eventually succeeds so that I am connected to a new server.  As I am logging the connection details it made more sense to use scp, and it must do most everything that ssh does, that is, verify authentication and make a connection to the remote host.

Here’s the command line I used, along with some initial lines from the output:

```text
scp -v -v somefile somuser@someserver:~/ | perltrace.pl | tee scp_trace.log
0.000027 Executing: program /usr/bin/ssh host someserver, user (unspecified), command scp -v -t ~/
0.000005 OpenSSH_4.3p2, OpenSSL 0.9.8b 04 May 2006
0.000003 debug1: Reading configuration data /etc/ssh/ssh_config
0.000003 debug1: Applying options for *
0.051990 debug2: ssh_connect: needpriv 0
0.003796 debug1: Connecting to someserver [192.168.1.80] port 22.
0.000146 debug1: Connection established.
0.000035 debug1: identity file /home/username/.ssh/identity type -1
0.000024 debug3: Not a RSA1 key file /home/username/.ssh/id_rsa.
...
```

Now with a log file in hand that included timing data, it was quite simple to isolate the ssh components that were consuming the most time:

```text
16:22:jkstill-22 > sort -n scp.log | tail -10
0.009709 debug1: expecting SSH2_MSG_KEX_DH_GEX_REPLY
0.010983 debug1: loaded 3 keys
0.043485 debug2: channel 0: rcvd adjust 131072
0.048267 debug1: SSH2_MSG_SERVICE_REQUEST sent
0.048332 debug2: channel 0: written 16 to efd 6
0.048438 debug1: expecting SSH2_MSG_KEX_DH_GEX_GROUP
0.051990 debug2: ssh_connect: needpriv 0
10.004512 debug2: we sent a publickey packet, wait for reply
20.026335 debug1: read PEM private key done: type RSA
60.053010 debug1: Entering interactive session..
```

I’ve done my bit – this information can be (and was) sent off to the system administrator to help troubleshoot the issue.

So, how does this all work? We can walk through the relevant bits of the code, and the scripts will be available for download.

First of all, here’s the help information

```text
$ perltrace.pl -help

perltrace.pl

usage: perltrace.pl - get timing information from program output

 perltrace.pl -cmdfirst|nocmdfirst -wallclock -totals

-cmdfirst     output precedes execution
-nocmdfirst   output follows exection
-wallclock    include wall clock time
-totals       include start,stop and total elapsed time

eg:

 perltrace.pl -option1 parameter1 -option2 parameter2 ...
 time scp -v -v  somefile somuser@someserver:~/ 2>&1 | perltrace.pl -cmdfirst > t.log
```

So that the perltrace can be tested, there is a shell script perltrace_ut_data.sh. The shell scripts performs a series of sleeps in a loop, optionally printing the command before or after it has occurred.  The entire script appears here:

perltrace_ut_data.sh:

```bash
#!/usr/bin/env bash

# default is show cmd first

usage () {
	echo $(basename $0)
	echo "-c show command then execute"
	echo "-n execute then show command"
}


while getopts cn arg
do
	case $arg in
		c) ORDER='CMDFIRST';;
		n) ORDER='NOCMDFIRST';;
		*) echo "invalid argument specified"; usage;exit 1;
	esac

done

# default to CMDFIRST
: ${ORDER:='CMDFIRST'}

echo "using $ORDER" >&2

for sleeptime in .5 .75 .25 .1 .9 1.2 .1 .2 .3
do
	if [ "$ORDER" == 'CMDFIRST' ]; then
		echo sleeping for $sleeptime seconds
		sleep $sleeptime
	else
		sleep $sleeptime
		echo sleeping for $sleeptime seconds
	fi
done
```

Here is an example of using perltrace_ut_data.sh to test and verify perltrace.pl:

```text
$ ./perltrace_ut_data.sh -c | perltrace.pl -cmdfirst -wallclock -totals
using CMDFIRST
2011-07-13 21:17:29 0.465963 sleeping for .5 seconds
2011-07-13 21:17:29 0.751859 sleeping for .75 seconds
2011-07-13 21:17:30 0.252734 sleeping for .25 seconds
2011-07-13 21:17:30 0.102787 sleeping for .1 seconds
2011-07-13 21:17:30 0.902740 sleeping for .9 seconds
2011-07-13 21:17:31 1.201655 sleeping for 1.2 seconds
2011-07-13 21:17:33 0.102713 sleeping for .1 seconds
2011-07-13 21:17:33 0.201860 sleeping for .2 seconds
2011-07-13 21:17:33 0.302074 sleeping for .3 seconds
Start Time: 2011-07-13 21:17:29
 End Time: 2011-07-13 21:17:33
 Elapsed: 4.285667
```

The guts of perltrace

Here I have included the relevant bits of perltrace.pl, stripped of debugging code and other extraneous bits that get in the way of understanding how it works.

First, the code, and then some explanations.

```perl
my @printline;
if ($cmdfirst){
 $printline[1]=''
}
my $firstline = 1;
while (<>) {
 chomp;
 $line=$_;
 shift @printline, push @printline,$line;
 # if this is the first line then we do not yet have timing information
 if ($firstline) {
 $firstline = 0;
 # pick up first line timing if -nocmdfirst
 unless ($cmdfirst) {
 ($endTime) = [gettimeofday];
 $tdiff = tv_interval($startTime, $endTime);
 printf "%s%$secondsFormat %sn", ($wallClock ? $wallClockTime . ' ' : '') , $tdiff,$printline[0];
 ($startTime) = [gettimeofday];
 $wallClockTime = strftime "%Y-%m-%d %H:%M:%S", localtime;
 }
 next;
 }
 ($endTime) = [gettimeofday];
 $tdiff = tv_interval($startTime, $endTime);
 printf "%s%$secondsFormat %sn", ($wallClock ? $wallClockTime . ' ' : '') , $tdiff,$printline[0];
 ($startTime) = [gettimeofday];
 $wallClockTime = strftime "%Y-%m-%d %H:%M:%S", localtime;
}
# pick up the last line if cmdfirst
# if no cmdfirst we already got timing info inside the loop
if ($cmdfirst) {
 shift @printline, push @printline,$line;
 $endTime=[gettimeofday];
 $tdiff = tv_interval($startTime, $endTime);
 printf "%s%$secondsFormat %sn", ($wallClock ? $wallClockTime . ' ' : '') , $tdiff,$printline[0];
}
```

Note: these line numbers no longer are correct due to changes in the code over time. Hopefully it is not too hard to follow along.


### Line 4

This line probably doesn’t look very important, but in fact it is the key to printing the timing information with the correct line from the input.

There are two different types of input we expect to see.  As specified by the perltrace.pl options they are -cmdfirst and -nocmdfirst, with -cmdfirst being the default.

-cmdfirst – This means we expect the text describing the operation to appear in the output before the operation is performed. This is the program that is being logged telling us “Here is what I am going to do”, and then doing it.
-nocmdfirst – What this means is that we expect to see the text describing the operation to appear in the output after the operation has been performed.  It is the program telling us “This is what I just did”

If we want to associated the time with the correct operation, it is necessary to know whether the diagnostic output appears before the operation, or after the operations.

So line 4 is used to ensure there are 2 elements in the printline array.  If the -nocmdfirst option is used, there will initially be no elements in the printline array.  This will make more sense as we go to line 14.

### Line 14

Here the topmost element of the array is shifted out.  If there are no elements then nothing is shifted out, and the array remains empty. So if the -cmdfirst option was used, the current line of input will be placed in $printline[1].   If -nocmdfirst is in force, then the current line of input will be in $printline[0].

### Lines 17-31

These lines deal with handling the first line of input from the pipe, and as such this block is executed only once.  If -nocmdfirst is enforced, we pick up the timing information and go to the top of the loop.  If however -cmdfirst is enforced, we skip the timing information.  Why skip it?  Since we expect the command to appear before it is executed, we just go back to the top of the loop and wait for the next line of input. When that line appears, we know the previous operation has completed and we can print the command and the timing operation.

### Lines 33-40

These lines are executed for every remaining line of input. Line 33 gets the current time, and line 35 computes the elapsed time for the current operation.  Line 37 is quite interesting, as this is the line that prints the output with the timing information.  If -wallclock was included as a command line option, the wall clock time will be at the beginning of the line.  Next will be the elapsed time, followed by the input text from the pipe.  You may have noticed that all the printf() statements always use $printline[0] as the text to print.  You may recall that the @printline array may have 1 or 2 elements in it, dependent on whether -nocmdfirst or -cmdfirst was used on the command line.  Line 4 ensures that the correct timing information is matched up with the input line by setting the array size.

### Lines 46-51

And finally these lines complete the job if -cmdfirst was used, as the final timing data is not known until the last line of input has been received and the program has exited the loop.

Other Uses

Since first writing perltrace.pl I have found other areas to use it. It has recently proved useful for timing parts of RMAN and rsync operations.

If you have are running a lengthy RMAN job, pipe the output through perltrace and then to a log file.  You can see in real time how much time each step requires.  Here’s the output from an operation to recatalog some backup files that were moved. Even if you don’t need the information right away, it is always nice to have an idea of how long it takes to perform various database operations.  I had no idea it would take so long to recatalog these backup pieces, as this was something I had never before done.

```text
$ORACLE_HOME/bin/rman target / catalog rman/PASSWORD@RMANCAT cmdfile recatalog_PRODRAC.rman  2>&1 | ~/bin/perltrace.pl -wallclock | tee RMAN_recatalog.log
2011-07-13 10:27:34 0.000084
2011-07-13 10:27:34 0.000016 Recovery Manager: Release 10.2.0.4.0 - Production on Wed Jul 13 10:27:34 2011
2011-07-13 10:27:34 0.000012
2011-07-13 10:27:34 0.000011 Copyright (c) 1982, 2007, Oracle.  All rights reserved.
2011-07-13 10:27:34 0.791405
2011-07-13 10:27:35 0.027189 connected to target database: PRODRAC (DBID=626198001)
2011-07-13 10:27:35 0.222686 connected to recovery catalog database
2011-07-13 10:27:35 0.012622
2011-07-13 10:27:36 0.010598 RMAN> catalog backuppiece '/mnt/archive/oracle/backups/archive2/PRODRAC2/PRODRAC_3981_1_sdmh3352_1_1_20110710.arc';
2011-07-13 10:27:36 0.010762 2> catalog backuppiece '/mnt/archive/oracle/backups/archive2/PRODRAC2/PRODRAC_3982_1_semh33ne_1_1_20110710.arc';
2011-07-13 10:27:36 0.011331 3> catalog backuppiece '/mnt/archive/oracle/backups/archive2/PRODRAC2/PRODRAC_3983_1_sfmh34ct_1_1_20110710.arc';
...
2011-07-13 10:35:09 0.000901 cataloged backuppiece
2011-07-13 10:35:09 21.824507 backup piece handle=/mnt/archive/oracle/backups/archive2/PRODRAC2/PRODRAC_3985_1_shmh358r_1_1_20110710.arc recid=11515 stamp=756383709
2011-07-13 10:35:31 21.281820
```

Even more recently I was using rsync to relocate a few hundred megabytes of archived logs to a new location.  By piping the output through perltrace I could see how time was required to copy each file  and then make a reasonable estimate as to how much more time was required to complete the job.  This was useful in forming an estimate of how much time it would take to copy all the files.

```text
oracle>  rsync -av --update  /mnt/rac/oracle/archive/PRODRAC /mnt/archive/oracle/archive |~/bin/perltrace.pl
0.897609 building file list ... done
0.848139 PRODRAC/
8.644107 PRODRAC/1_1610_755849488.dbf
10.221037 PRODRAC/1_1611_755849488.dbf
20.903755 PRODRAC/2_1401_755849488.dbf
22.600272 PRODRAC/2_1402_755849488.dbf
21.960984 PRODRAC/2_1403_755849488.dbf
22.321083 PRODRAC/2_1404_755849488.dbf
22.843627 PRODRAC/2_1405_755849488.dbf
20.304977 PRODRAC/2_1406_755849488.dbf
...
```

If you have ever used tail -f to watch the oracle alert log for changes such as the application of archive logs during a database recovery, you may have wanted to know just how much time was required to apply each log.  Oracle does provide date stamps before and after the log, but you are left calculating the time yourself.  This can easily accomplished by piping the output of tail -f through perltrace.  I don’t have any results handy for this one, but the command line is simple enough:

`$ tail -f alert_orcl.log | perltrace -wallclock`


The first few lines will of course have incorrect timing information, as those lines already exist in the file.  This method works for any log file that is continuously written to.

