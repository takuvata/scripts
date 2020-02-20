#!/bin/bash

[ -z $DBIO_W_P_COUNT ] && DBIO_W_P_COUNT=5
[ -z $DBIO_W_RECORD_COUNT ] && DBIO_RECORD_COUNT=10
[ -z $DBIO_R_P_COUNT ] && DBIO_R_P_COUNT=5

[ -z $DBIO_W_SLEEP ] && DBIO_W_SLEEP=1
[ -z $DBIO_R_SLEEP ] && DBIO_R_SLEEP=1

[ -z $DBIO_HOST ] && DBIO_HOST=localhost
[ -z $DBIO_PORT ] && DBIO_PORT=3306
[ -z $DBIO_USER ] && DBIO_USER=dbio
[ -z $DBIO_PASSWORD ] && DBIO_PASSWORD=dbio
[ -z $DBIO_DB ] && DBIO_DB=dbio
[ -z $DBIO_TABLE ] && DBIO_TABLE=dbio

which pkill &>/dev/null || exit 1
which mysql &>/dev/null || exit 1

DBIO_PIPE=$(mktemp -u -t dbio_pipe.XXXXXXXXX)
mkfifo $DBIO_PIPE

CLIENT="mysql -h ${DBIO_HOST} -P ${DBIO_PORT} -u $DBIO_USER --password=$DBIO_PASSWORD $DBIO_DB -e"

cleanup(){
  pkill -P $$
  rm -f ${DBIO_PIPE}
  $CLIENT "drop table $DBIO_TABLE;"
}

dbio_init() {
  echo -n Initializing data set...
  $CLIENT "CREATE TABLE IF NOT EXISTS $DBIO_TABLE (id INT AUTO_INCREMENT PRIMARY KEY, data INT NOT NULL ) ENGINE=INNODB;"
  for record in $(seq 1 $DBIO_RECORD_COUNT); do
    $CLIENT "INSERT INTO $DBIO_TABLE (data) VALUES($[$RANDOM % 100]);"
  done
  echo done
}

dbio_write() {
  while :; do
    (
      $CLIENT "UPDATE $DBIO_TABLE SET data = $[$RANDOM % 100] WHERE id = $[$RANDOM % $DBIO_RECORD_COUNT + 1];" &>/dev/null &&\
      echo 0 > $DBIO_PIPE ||\
      echo 10 > $DBIO_PIPE
    )
    [ -z $DBIO_W_SLEEP ] || sleep $[$RANDOM % ($DBIO_W_SLEEP + 1)]
  done
}

dbio_read() {
  while :; do
    (
      $CLIENT "SELECT data FROM $DBIO_TABLE WHERE id = $[$RANDOM % $DBIO_RECORD_COUNT + 1];" &> /dev/null &&\
      echo 1 > $DBIO_PIPE ||\
      echo 11 > $DBIO_PIPE
    )
    [ -z $DBIO_R_SLEEP ] || sleep $[$RANDOM % ($DBIO_R_SLEEP + 1) ]
  done
}

trap "cleanup; exit 0" SIGHUP SIGINT SIGTERM

echo Starting with $DBIO_W_P_COUNT write, $DBIO_R_P_COUNT read processes.

dbio_init

for w_process in $(seq 1 $DBIO_W_P_COUNT); do 
  dbio_write &
done

for r_process in $(seq 1 $DBIO_R_P_COUNT); do 
  dbio_read &
done

reads=0
read_err=0
writes=0
write_err=0
time_start=$(date +%s)
timer=$time_start
echo ----------------
echo Every 5 seconds:
printf '%8s %8s %8s %8s %8s\n' 'Time' 'Writes' 'Reads' 'WErr' 'RErr'
while :; do
  for event in $(<$DBIO_PIPE); do
    case $event in
      1)
        reads=$[$reads + 1]
      ;;
      11)
        read_err=$[$read_err + 1]
      ;;
      0)
        writes=$[$writes + 1]
      ;;
      10)
        write_err=$[$write_err + 1]
      ;;
    esac
  done
  now=$(date +%s)
  if [ $[$now - $timer] -gt 4 ]; then
    printf '%8s %8s %8s %8s %8s\n' $[$now - $time_start] $writes $reads $write_err $read_err
    reads=0
    writes=0
    read_err=0
    write_err=0
    timer=$now
  fi
done
