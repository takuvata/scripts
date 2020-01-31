#!/bin/bash

[ -z $STRS_W_P_COUNT ] && STRS_W_P_COUNT=16
[ -z $STRS_W_F_COUNT ] && STRS_W_F_COUNT=100000
[ -z $STRS_R_P_COUNT ] && STRS_R_P_COUNT=128
[ -z $STRS_F_SIZE ] && STRS_F_SIZE=5120

[ -z $STRS_W_SLEEP ] && STRS_W_SLEEP=2
[ -z $STRS_R_SLEEP ] && STRS_R_SLEEP=

[ -z $STRS_BASE_PATH ] && STRS_BASE_PATH=.

which pkill &>/dev/null || exit 1

STRS_W_DIR=$(mktemp -d --tmpdir=$STRS_BASE_PATH -t fstress_data.XXXXXXXXX) || exit 1

STRS_PIPE=$(mktemp -u -t fstress_pipe.XXXXXXXXX)
mkfifo $STRS_PIPE

cleanup(){
  pkill -P $$
  rm -fr ${STRS_W_DIR}
  rm -f ${STRS_PIPE}
}

strs_init() {
  echo -n Initializing data set...
  for process in $(seq 1 $STRS_W_P_COUNT); do
    mkdir ${STRS_W_DIR}/${process}
    for file in $(seq 1 $STRS_W_F_COUNT); do
      if ! dd if=/dev/zero of=${STRS_W_DIR}/${process}/${file} bs=$STRS_F_SIZE count=1 &>/dev/null; then
        echo failed
        cleanup
        exit 1
      fi
    done
  done
  echo done
  echo Data set: $(du -sh $STRS_W_DIR)
}

strs_write() {
  while :; do
    [ -d ${STRS_W_DIR}/${1} ] || mkdir ${STRS_W_DIR}/${1}
    # For whatever reason reporting status to the pipe, somehow manages to kill the parent process eventualy.
    # To mitigate the problem just put this bit in to a subshell.
    # If someone could explain this to me properly - I owe you lots of beer!
   ( dd if=/dev/urandom of=${STRS_W_DIR}/${1}/$[$RANDOM % $STRS_W_F_COUNT + 1] bs=$STRS_F_SIZE count=1 &>/dev/null &&\
     echo 0 > $STRS_PIPE )
    [ -z $STRS_W_SLEEP ] || sleep $[$RANDOM % ($STRS_W_SLEEP + 1)]
  done
}

strs_read() {
  while :; do
    # Same as in write.
    ( dd if=${STRS_W_DIR}/$[$RANDOM % $STRS_W_P_COUNT + 1]/$[$RANDOM % $STRS_W_F_COUNT + 1] of=/dev/null &> /dev/null &&\
      echo 1 > $STRS_PIPE )
    [ -z $STRS_R_SLEEP ] || sleep $[$RANDOM % ($STRS_R_SLEEP + 1) ]
  done
}

trap "cleanup; exit 0" SIGHUP SIGINT SIGTERM

echo Starting with $STRS_W_P_COUNT write, $STRS_R_P_COUNT read processes.
echo File size: $STRS_F_SIZE bytes.
echo Each write process handles $STRS_W_F_COUNT files.

[[ $1 == '--skip_init'  ]] || strs_init

if [ -z $STRS_W_SLEEP ]; then
  echo Writes never stop.
else
  echo Up to $STRS_W_SLEEP seconds pause after a write for each process.
fi
if [ -z $STRS_R_SLEEP ]; then
  echo Reads never stop.
else
  echo Up to $STRS_R_SLEEP seconds pause after a read for each process.
fi

for w_process in $(seq 1 $STRS_W_P_COUNT); do 
  strs_write $w_process &
done

for r_process in $(seq 1 $STRS_R_P_COUNT); do 
  strs_read &
done

reads=0
writes=0
time_start=$(date +%s)
timer=$time_start
echo ----------------
echo Every 5 seconds:
printf '%8s %8s %8s\n' 'Time' 'Writes' 'Reads'
while :; do
  for event in $(<$STRS_PIPE); do
    if [ $event -eq 1 ]; then
      reads=$[$reads + 1]
    else
      writes=$[$writes + 1]
    fi
  done
  now=$(date +%s)
  if [ $[$now - $timer] -gt 4 ]; then
    printf '%8s %8s %8s\n' $[$now - $time_start] $writes $reads
    reads=0
    writes=0
    timer=$now
  fi
done
