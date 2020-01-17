#Fstress
A naive script to stress load a file system with many parallel reads/writes. It is not a benchmark.
##Environment Variables
Following environment variables can be exported to tweak the behaviour:
  * STRS_W_P_COUNT - how many subprocesses are created for writing.
  * STRS_R_P_COUNT - how many subprocesses are created for reading.
  * STRS_W_F_COUNT - how many files each writing subprocess will handle.
  * STRS_F_SIZE - the size of each file for reading/writting.
  * STRS_W_SLEEP - number of seconds up to which each process will sleep after a write (randomized).
  * STRS_P_SLEEP - number of seconds up to which each process will sleep after a read (randomized).
  * STRS_BASE_PATH - a file system path where data set is created.

The default values are set for a heavy random read on large number of small files.
