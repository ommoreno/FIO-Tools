#!/bin/bash


IOENGINE="libaio"
THREAD=true
TIME_BASED=true
NORANDOMMAP=true
DIRECT=1
RANDREPEAT=1
CLIENTNAME="admin"
POOL="rbd"

RAMP_TIME=200
RUN_TIME=300
ITERATIONS=1
SLEEP_TIME=60

blockSize=(4K 16K 64K 1M 4M)
rw_mixRead=(0 50 100)
iodepth=(1 2 4 8 16 32 64)
rw=(randrw rw)
numJobs=(1 2 4 8)
devices=(nvme0n1 nvme1n1 nvme2n1 nvme3n1)

if [ "$1" == "" ]
then
	dateOut=$(date +%Y%m%d-%H%M)
	OUTDIR="${dateOut}_fio_${IOENGINE}_results"
else
	OUTDIR=$1
fi
[ -d $OUTDIR ] || mkdir $OUTDIR

jobFile="fio.job"
cat > $jobFile << EOL
[global]
ioengine=${IOENGINE}
direct=${DIRECT}
randrepeat=${RANDREPEAT}
ramp_time=${RAMP_TIME}
runtime=${RUN_TIME}
EOL
if [ "$THREAD" == true ]
then
	echo "thread" >> $jobFile
fi
if [ "$TIME_BASED" == true ]
then
	echo "time_based" >> $jobFile
fi
if [ "$NORANDOMMAP" == true ]
then
	echo "norandommap" >> $jobFile
fi
if [ "$IOENGINE" == "rbd" ]
then
	echo "pool=$POOL" >> $jobFile
	echo "clientname=$CLIENTNAME" >> $jobFile
fi
for dev in ${devices[@]}
do
		echo "[${dev}]" >> $jobFile
		if [ "$IOENGINE" == "rbd" ]
		then
			echo "rbdname=$dev" >> $jobFile
		else
			echo "filename=/dev/${dev}" >> $jobFile
		fi
done

for bs in ${blockSize[@]}
do
	for mix in ${rw_mixRead[@]}
	do
		for qd in ${iodepth[@]}
		do
			for seek in ${rw[@]}
			do
				for j in ${numJobs[@]}
				do	
					for (( i=0; i < $ITERATIONS; i++ ))
					do
						outputFile="${bs}_${mix}read_${qd}qd_${seek}_${j}job_run${i}"
						echo "START_TEST ("$outputFile"): $(date)"
						sudo fio --blocksize=$bs --rwmixread=$mix --iodepth=$qd --rw=$seek --numjobs=$j $jobFile > ${OUTDIR}/${outputFile}_fio.out &
						sleep $RAMP_TIME
						dstat -tcmyd --disk-util -n --output ${OUTDIR}/${outputFile}_dstat.csv 1 $RUN_TIME > /dev/null &
						iostat -ytxkz 1 $RUN_TIME > ${OUTDIR}/${outputFile}_iostat.out &
						#sar -p 1 $RUN_TIME > ${OUTDIR}/${outputFile}_sar.out &
						#dstat -tcmyd --full -n --output ${outputFile}_dstat.csv 1 $RUN_TIME &
						wait
						echo "END_TEST ("$outputFile"): $(date)"
						echo "STATUS: sleeping between runs..."
						sleep $SLEEP_TIME
					done
				done
			done
		done
	done
done

mv $jobFile $OUTDIR

