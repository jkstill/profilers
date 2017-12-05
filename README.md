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

                      Call       Count          Elapsed             Avg ms
                arch_prctl           1         0.000002         0.00200000
                   geteuid           1         0.000002         0.00200000
           set_tid_address           1         0.000002         0.00200000
            rt_sigprocmask           1         0.000002         0.00200000
           set_robust_list           1         0.000002         0.00200000
                 getrlimit           1         0.000002         0.00200000
                 fadvise64           1         0.000004         0.00400000
              rt_sigaction           2         0.000005         0.00250000
                       brk           3         0.000007         0.00233333
                    statfs           2         0.000012         0.00600000
                     lseek           1         0.000017         0.01700000
                    access           9         0.000035         0.00388889
                    munmap           2         0.000087         0.04350000
                  mprotect          16         0.000088         0.00550000
                    execve           1         0.000092         0.09200000
                      mmap          24         0.000111         0.00462500
                     fstat          11         0.000334         0.03036364
                      stat           7         0.009231         1.31871429
                     write         782         0.029311         0.03748210
                      open          21         0.083619         3.98185714
                      read         792         0.264745         0.33427399
                     close          14         4.856663       346.90450000

 ~/profilers $ ./strace-breakdown.pl cp-without-PID.trc

  Total Counted Time:   5.32735400
  Total Elapsed Time:   5.35226488
  Unaccounted for Time: 0.02491088

                      Call       Count          Elapsed             Avg ms
                arch_prctl           1         0.000002         0.00200000
                   geteuid           1         0.000003         0.00300000
                     lseek           1         0.000003         0.00300000
           set_robust_list           1         0.000003         0.00300000
           set_tid_address           1         0.000003         0.00300000
            rt_sigprocmask           1         0.000003         0.00300000
                 getrlimit           1         0.000003         0.00300000
                 fadvise64           1         0.000004         0.00400000
              rt_sigaction           2         0.000005         0.00250000
                       brk           3         0.000009         0.00300000
                    statfs           2         0.000018         0.00900000
                    munmap           2         0.000030         0.01500000
                    access           9         0.000036         0.00400000
                      mmap          24         0.000113         0.00470833
                    execve           1         0.000114         0.11400000
                  mprotect          16         0.000116         0.00725000
                     fstat          11         0.000328         0.02981818
                      stat           7         0.009672         1.38171429
                     write         782         0.034919         0.04465345
                      open          21         0.098066         4.66980952
                      read         792         0.264842         0.33439646
                     close          14         4.919062       351.36157143

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





