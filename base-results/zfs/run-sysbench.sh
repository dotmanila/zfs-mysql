#!/bin/bash

SZ=20000000
TBL=32
THD=$2
SLEEP=120
TS=7200
PREFIX=$1

#time sysbench --db-driver=mysql --mysql-user=msandbox --mysql-password=msandbox \
#    --mysql-db=test --mysql-host=127.0.0.1 --mysql-port=57190 --tables=$TBL \
#    --table-size=$SZ --auto-inc=off --threads=$THD --time=0 \
#    --rand-type=pareto oltp_read_only cleanup

if [ "x$3" == "xprepare" ]; then
time sysbench --db-driver=mysql --mysql-user=msandbox --mysql-password=msandbox \
    --mysql-db=test --mysql-host=127.0.0.1 --mysql-port=57190 --tables=$TBL \
    --table-size=$SZ --auto-inc=off --threads=8 --time=0 \
    --rand-type=pareto oltp_read_only prepare 2>&1 | tee zfs-run-${PREFIX}-prepare.txt
elif [ "x$3" == "xwarmup" ]; then
time sysbench --db-driver=mysql --mysql-user=msandbox --mysql-password=msandbox \
    --mysql-db=test --mysql-host=127.0.0.1 --mysql-port=57190 --tables=$TBL \
    --table-size=$SZ --auto-inc=off --threads=16 --time=$TS \
    --rand-type=pareto --report-interval=1 oltp_read_only run

sleep $SLEEP
fi

> zfs-ds-${PREFIX}-read-write.txt
(
while true; do
   date +"TS %s.%N %F %T" >> zfs-ds-${PREFIX}-read-write.txt && \
   cat /proc/diskstats >> zfs-ds-${PREFIX}-read-write.txt && \
   sleep 1;
done) &
DSPID=$!

#( sudo zpool iostat -v 1 $TS > zfs-iostat-${PREFIX}-read-write.txt 2>&1 ) &
( sudo zpool iostat -pvlq 1 $TS > zfs-iostat-${PREFIX}-read-write.txt 2>&1 ) &
( vmstat 1 $TS > zfs-vmstat-${PREFIX}-read-write.txt 2>&1 ) &

time sysbench --db-driver=mysql --mysql-user=msandbox --mysql-password=msandbox \
    --mysql-db=test --mysql-host=127.0.0.1 --mysql-port=57190 --tables=$TBL \
    --table-size=$SZ --auto-inc=off --threads=$THD --time=$TS \
    --rand-type=pareto --report-interval=1 oltp_read_write run 2>&1 | tee zfs-run-${PREFIX}-read-write.txt

kill $DSPID
sleep $SLEEP

> zfs-ds-${PREFIX}-update-index.txt
(
while true; do
   date +"TS %s.%N %F %T" >> zfs-ds-${PREFIX}-update-index.txt && \
   cat /proc/diskstats >> zfs-ds-${PREFIX}-update-index.txt && \
   sleep 1;
done) &
DSPID=$!

#( sudo zpool iostat -v 1 $TS > zfs-iostat-${PREFIX}-update-index.txt 2>&1 ) &
( sudo zpool iostat -pvlq 1 $TS > zfs-iostat-${PREFIX}-update-index.txt 2>&1 ) &
( vmstat 1 $TS > zfs-vmstat-${PREFIX}-update-index.txt 2>&1 ) &

time sysbench --db-driver=mysql --mysql-user=msandbox --mysql-password=msandbox \
    --mysql-db=test --mysql-host=127.0.0.1 --mysql-port=57190 --tables=$TBL \
    --table-size=$SZ --auto-inc=off --threads=$THD --time=$TS \
    --rand-type=pareto --report-interval=1 oltp_update_index run 2>&1 | tee zfs-run-${PREFIX}-update-index.txt

kill $DSPID
sleep $SLEEP

> zfs-ds-${PREFIX}-read-only.txt
(
while true; do
   date +"TS %s.%N %F %T" >> zfs-ds-${PREFIX}-read-only.txt && \
   cat /proc/diskstats >> zfs-ds-${PREFIX}-read-only.txt && \
   sleep 1;
done) &
DSPID=$!

#( sudo zpool iostat -v 1 $TS > zfs-iostat-${PREFIX}-read-only.txt 2>&1 ) &
( sudo zpool iostat -pvlq 1 $TS > zfs-iostat-${PREFIX}-read-only.txt 2>&1 ) &
( vmstat 1 $TS > zfs-vmstat-${PREFIX}-read-only.txt 2>&1 ) &

time sysbench --db-driver=mysql --mysql-user=msandbox --mysql-password=msandbox \
    --mysql-db=test --mysql-host=127.0.0.1 --mysql-port=57190 --tables=$TBL \
    --table-size=$SZ --auto-inc=off --threads=$THD --time=$TS \
    --rand-type=pareto --report-interval=1 oltp_read_only run 2>&1 | tee zfs-run-${PREFIX}-read-only.txt

kill $DSPID
