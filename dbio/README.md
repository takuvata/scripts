# Fstress
A script to create continuous writes and reads to a database to simulate usage. Found it useful while testing HA setup. It is not a benchmark.
## Environment Variables
Following environment variables can be exported to tweak the behaviour:
  * DBIO_W_P_COUNT - how many subprocesses are created for writing.
  * DBIO_R_P_COUNT - how many subprocesses are created for reading.
  * DBIO_W_SLEEP - number of seconds up to which each process will sleep after a write (randomized).
  * DBIO_P_SLEEP - number of seconds up to which each process will sleep after a read (randomized).
  * DBIO_W_RECORD_COUNT - number of rows in a table.
  * DBIO_HOST - database server host.
  * DBIO_PORT - database server port.
  * DBIO_USER - databse user.
  * DBIO_PASSWORD - database password.
  * DBIO_DB - database name (must exist).
  * DBIO_TABLE - database table name.
