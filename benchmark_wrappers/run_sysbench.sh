#!/bin/bash

[ -z "$_TESTS" -o \
  -z "$_THREADS" -o \
  -z "$_SIZE" ] && {
cat <<EOF>&2

   usage: [env var1=val1 var2=val2 ...] $0
   No direct input args, behavior is controlled by the following environment
   variables: 
     - _EXP_NAME : Experiment name. Optional, defaults to 'sysbench'
     - _TESTS : Quoted list of the tests to run, i.e. "oltp_read_only
       oltp_read_write".
     - _THREADS : Quoted list of the # of threads to use for each run, i.e.
       "16 32 64"
     - _SIZE : Quoted list of the table sizes to use, in rows, i.e.
       "100000 1000000 10000000"
   
   Any actual input argument will be passed as is to sysbench, so you can run
   this like so:

   env _TESTS="oltp_read_only oltp_read_write" _THREADS="16 32" _SIZE="1000 10000" $0 --rand-type=pareto --rand-init=on --report-interval=10 --mysql-host=sbhost --mysql-db=sbtest --max-time=7200 --max-requests=0

   env _EXP_NAME=sample _TESTS="oltp_read_only oltp_read_write" _THREADS="1 2 4" _SIZE="10 100" ./run_sysbench.sh --oltp_tables_count=2 --mysql-user=sysbench --mysql-password=sysbench --mysql_table_engine=innodb --rand-type=pareto --rand-init=on --report-interval=10 --mysql-db=sbtest --max-time=5 --max-requests=0 


EOF

exit 1

}

[ -z "$_EXP_NAME" ] && _EXP_NAME="sysbench"

SCRIPT_ROOT=$(dirname $(readlink -f $0))
TEST_DIR=${SCRIPT_ROOT}/../sysbench_tests

for test in $_TESTS; do
    test_path=${TEST_DIR}/${test}.lua

    if [[ ! -f ${test_path} ]]; then
        echo "Skipping test ${test}, as it is not yet supported"
        continue
    fi

    mkdir $test 2>/dev/null #ignore if it exists
    pushd $test
    for threads in $_THREADS; do
	for size in $_SIZE; do
	    echo "Starting sysbench for test=$test, threads=$threads, size=$size" 
	    sysbench ${test_path} --threads=$threads --table-size=$size $* prepare
	    sysbench ${test_path} --threads=$threads --table-size=$size $* run | tee $_EXP_NAME.thr$threads.sz$size.test$test.txt 
	    sysbench ${test_path} --threads=$threads --table-size=$size $* cleanup
        done
    done
    popd
done
