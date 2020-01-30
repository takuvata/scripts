#!/bin/bash

[ -z $STRS_W_P_COUNT ] && STRS_W_P_COUNT=6
[ -z $STRS_W_F_COUNT ] && STRS_W_F_COUNT=10000
[ -z $STRS_R_P_COUNT ] && STRS_R_P_COUNT=16
[ -z $STRS_F_SIZE ] && STRS_F_SIZE=5120

[ -z $STRS_W_SLEEP ] && STRS_W_SLEEP=3
[ -z $STRS_R_SLEEP ] && STRS_R_SLEEP=

[ -z $STRS_BASE_PATH ] && STRS_BASE_PATH=.

which pkill &>/dev/null || exit 1

STRS_W_DIR=$(mktemp -d --tmpdir=$STRS_BASE_PATH -t fstress.XXXXXXXXX) || exit 1

STRS_PIPE=$(mktemp -u)
mkpipe $STRS_PIPE

strs_init() {
  echo -n Initializing data set...
  for process in $(seq 1 $STRS_W_P_COUNT); do
    mkdir ${STRS_W_DIR}/${process}
    for file in $(seq 1 $STRS_W_F_COUNT); do
      if ! dd if=/dev/urandom of=${STRS_W_DIR}/${process}/${file} bs=$STRS_F_SIZE count=1 &>/dev/null; then
        echo failed
        rm -fr ${STRS_W_DIR}
        rm -f ${STRS_PIPE}
        exit 1
      fi
    done
  done
  echo done
}

strs_write() {
  while :; do
    dd if=/dev/urandom of=${STRS_W_DIR}/${1}/$[$RANDOM % $STRS_W_F_COUNT + 1] bs=$STRS_F_SIZE count=1 &>/dev/null
    echo 0 > $STRS_PIPE
    [ -z $STRS_W_SLEEP ] || sleep $[$RANDOM % ($STRS_W_SLEEP + 1)]
  done
}

strs_read() {
  while :; do
    dd if=${STRS_W_DIR}/$[$RANDOM % $STRS_W_P_COUNT + 1]/$[$RANDOM % $STRS_W_F_COUNT + 1] of=/dev/null &> /dev/null
    echo 1 > $STRS_PIPE
    [ -z $STRS_R_SLEEP ] || sleep $[$RANDOM % ($STRS_R_SLEEP + 1) ]
  done
}

trap "pkill -P $$; rm -fr ${STRS_W_DIR}; rm -f ${STRS_PIPE}; exit 0" SIGHUP SIGINT SIGTERM

echo Starting with $STRS_W_P_COUNT write, $STRS_R_P_COUNT read processes.
echo File size: $STRS_F_SIZE bytes.
echo Each write process handles $STRS_W_F_COUNT files.

strs_init

echo Data set: $(du -sh $STRS_W_DIR)
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
timer=$(date +%s)
while :; do
  for event in $(<$STRS_PIPE); do
    if [ $event -eq 1 ]; then
      reads=$[$reads + 1]
    else
      writes=$[$writes + 1]
    fi
  done
  now=$(date +%s)
  if [ $[$now - $timer] -gt 5 ]; then
    echo $reads files read
    echo $writes files written
    timer=$now
  fi
done
