# profilers
Profilers of various sorts, starting with simple strace profilers


# strace

Here are a couple of simple strace profilers with sample results

## strace-prof.pl

```shell

 ~/profilers $ ./strace-prof.pl cp-with-PID.trc

  Total Counted Time:        5.24
  Total Elapsed Time:        5.27
  Unaccounted for Time:      0.02

 ~/profilers $ ./strace-prof.pl cp-without-PID.trc

  Total Counted Time:        5.33
  Total Elapsed Time:        5.35
  Unaccounted for Time:      0.02

```

## strace-breakdown.pl

```shell
 ~/profilers $ ./strace-breakdown.pl cp-with-PID.trc

  Total Counted Time:   5.24437300
  Total Elapsed Time:   5.26540518
  Unaccounted for Time: 0.02103218

                      Call       Count          Elapsed                Min             Max          Avg ms
            rt_sigprocmask           1           0.000002         0.000002        0.000002        0.000002
                 getrlimit           1           0.000002         0.000002        0.000002        0.000002
                   geteuid           1           0.000002         0.000002        0.000002        0.000002
           set_robust_list           1           0.000002         0.000002        0.000002        0.000002
                arch_prctl           1           0.000002         0.000002        0.000002        0.000002
           set_tid_address           1           0.000002         0.000002        0.000002        0.000002
                 fadvise64           1           0.000004         0.000004        0.000004        0.000004
              rt_sigaction           2           0.000005         0.000002        0.000003        0.000002
                       brk           3           0.000007         0.000002        0.000003        0.000002
                    statfs           2           0.000012         0.000003        0.000009        0.000006
                     lseek           1           0.000017         0.000017        0.000017        0.000017
                    access           9           0.000035         0.000003        0.000005        0.000004
                    munmap           2           0.000087         0.000008        0.000079        0.000044
                  mprotect          16           0.000088         0.000005        0.000008        0.000005
                    execve           1           0.000092         0.000092        0.000092        0.000092
                      mmap          24           0.000111         0.000003        0.000014        0.000005
                     fstat          11           0.000334         0.000002        0.000308        0.000030
                      stat           7           0.009231         0.000002        0.007259        0.001319
                     write         782           0.029311         0.000012        0.000098        0.000037
                      open          21           0.083619         0.000003        0.081737        0.003982
                      read         792           0.264745         0.000002        0.003799        0.000334
                     close          14           4.856663         0.000002        4.856545        0.346904

 ~/profilers $ ./strace-breakdown.pl cp-without-PID.trc

  Total Counted Time:   5.32735400
  Total Elapsed Time:   5.35226488
  Unaccounted for Time: 0.02491088

                      Call       Count          Elapsed                Min             Max          Avg ms
                arch_prctl           1           0.000002         0.000002        0.000002        0.000002
           set_robust_list           1           0.000003         0.000003        0.000003        0.000003
           set_tid_address           1           0.000003         0.000003        0.000003        0.000003
                   geteuid           1           0.000003         0.000003        0.000003        0.000003
                 getrlimit           1           0.000003         0.000003        0.000003        0.000003
                     lseek           1           0.000003         0.000003        0.000003        0.000003
            rt_sigprocmask           1           0.000003         0.000003        0.000003        0.000003
                 fadvise64           1           0.000004         0.000004        0.000004        0.000004
              rt_sigaction           2           0.000005         0.000002        0.000003        0.000002
                       brk           3           0.000009         0.000002        0.000004        0.000003
                    statfs           2           0.000018         0.000005        0.000013        0.000009
                    munmap           2           0.000030         0.000012        0.000018        0.000015
                    access           9           0.000036         0.000003        0.000005        0.000004
                      mmap          24           0.000113         0.000002        0.000008        0.000005
                    execve           1           0.000114         0.000114        0.000114        0.000114
                  mprotect          16           0.000116         0.000005        0.000009        0.000007
                     fstat          11           0.000328         0.000002        0.000301        0.000030
                      stat           7           0.009672         0.000003        0.007777        0.001382
                     write         782           0.034919         0.000011        0.000143        0.000045
                      open          21           0.098066         0.000003        0.096109        0.004670
                      read         792           0.264842         0.000002        0.001394        0.000334
                     close          14           4.919062         0.000002        4.919019        0.351362

```

## Create test trace files


Create a test file

```shell
  dd if=/dev/zero bs=4096 count=25000 of=/mnt/common/temp/bigfile.dat 
```

 
The tracefile cp-with-PID.trc will have a PID as the first column

```shell
   strace -ttt -T -f -o cp-with-PID.trc cp /mnt/common/temp/bigfile.dat /mnt/zips/moriarty/tmp/bigfile.dat
```

The tracefile cp-with-PID.trc  will not have a PID

```shell
   strace -ttt -T -o cp-without-PID.trc cp /mnt/common/temp/bigfile.dat /mnt/zips/moriarty/tmp/bigfile.dat
```


# 10046 Oracle trace files

## bind-exe-stats.pl

Display execution stats per set of bind variables as found in a 10046 trace.

This is useful for locating predicatetes that cause lengthy execution time, often due to skewed data.

### Help

```
    bind-exe-stats.pl

    usage: bind-exe-stats.pl - print execution stats per bind variable set from 10046 trace

    bind-exe-stats.pl --cursor-id --sql-fragment  --help

    --cursor-id ID of the cursor as seen in 10046 file

      example: the following cursor ID is 139665751367648

      PARSING IN CURSOR #139665751367648 len=34 dep=1 uid=104 oct=3 lid=104 tim=1561698984944 hv=1868446218 ad='7c5d6e00' sqlid='g4bamjjrpwfha'
      select c1 from ct where id = :n_id

    --sql-fragment  Some (or all) of the SQL statement being profiled

       This is necessary as the cursor ID's may get re-used.
       There is the possibility that not all instances of the SQL statement will be profiled
       A future enhancement may fix that.

example:

bind-exe-stats.pl --cursor-id 139665751367648 --sql-fragment 'select c1 from ct where id'

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
```



# sprof.pl

Profile an strace file

```shell

strace -tt -T -f -o ls.trc ls -l 

./sprof.pl --file ls.trc

>  ./sprof.pl --file ls.trc
=== arch_prctl ===
   count: 1
   time : 0.000002
=== close ===
   count: 42
   time : 0.000118
=== execve ===
   count: 12
   time : 0.001656
=== fstat ===
   count: 35
   time : 0.000100
=== getdents ===
   count: 2
   time : 0.000012
=== getrlimit ===
   count: 5
   time : 0.000015
=== ioctl ===
   count: 2
   time : 0.000008
=== lseek ===
   count: 5
   time : 0.000011
=== lstat ===
   count: 9
   time : 0.000030
=== mprotect ===
   count: 34
   time : 0.000244
=== munmap ===
   count: 6
   time : 0.000042
=== open ===
   count: 18
   time : 0.000099
=== read ===
   count: 15
   time : 0.000072
=== rt_sigaction ===
   count: 2
   time : 0.000005
=== rt_sigprocmask ===
   count: 1
   time : 0.000002
=== set_robust_list ===
   count: 1
   time : 0.000003
=== set_tid_address ===
   count: 1
   time : 0.000002
=== socket ===
   count: 8
   time : 0.000038
=== stat ===
   count: 3
   time : 0.000021
=== write ===
   count: 4
   time : 0.000600


Elapsed Seconds: 0.004365
SyscallTime    : 0.003080
Unaccounted For: 0.001285

Unaccounted For Time: 10046 overhead, strace overhead, db time
```


