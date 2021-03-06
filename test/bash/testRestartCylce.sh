#! /bin/bash

. $BLJ/script/blj_functions

useDocker=$([ ${#1} -gt 0 ] && [ $1 == "docker" ] && echo "true" || echo "false" )
if [ $useDocker == "true" ]; then
	echo "Use docker"
	dOpt="-d --blj -e SHEP=$SHEP"
else 
	echo "Don't use docker"
	dOpt=""
fi
echo ""

MY_PIPELINES=${SHEP}/test/bash/pipelines
rm -rf $MY_PIPELINES
export BLJ_PROJ=$MY_PIPELINES
[ ! -d $BLJ_PROJ ] && mkdir -p $BLJ_PROJ/previousDir

echo ""
echo "Part 1"
CMD1="biolockj --external-modules ${SHEP}/MockMain/dist $dOpt \
         ${SHEP}/test/bash/configFile/configToFail.properties"
echo $CMD1
$CMD1
        
RESTART_DIR=$(most_recent_pipeline)
while [ -f $RESTART_DIR/biolockjStarted ]; do sleep 1; done

cp -r $RESTART_DIR ${RESTART_DIR}_run1

echo ""
echo "Part 2"
CMD2="biolockj --external-modules ${SHEP}/MockMain/dist $dOpt \
		 --restart $RESTART_DIR"
echo "$CMD2"
$CMD2

while [ -f $RESTART_DIR/biolockjStarted ]; do sleep 1; done

cp -r $RESTART_DIR ${RESTART_DIR}_run2

MASTER_PROP=$(ls $RESTART_DIR/MASTER*.properties)
echo "configToFail.fail=N" >> $MASTER_PROP


echo ""
echo "Part 3"
echo "$CMD2"
$CMD2

while [ -f $RESTART_DIR/biolockjStarted ]; do sleep 1; done

run1_mod3=$( cat ${RESTART_DIR}_run1/03*/output/*txt )
run1_mod4=$( cat ${RESTART_DIR}_run1/04*/output/*txt )
run2_mod3=$( cat ${RESTART_DIR}_run2/03*/output/*txt )
run2_mod4=$( cat ${RESTART_DIR}_run2/04*/output/*txt )
run3_mod3=$( cat ${RESTART_DIR}/03*/output/*txt )
run3_mod4=$( cat ${RESTART_DIR}/04*/output/*txt )

failures=0

if [ "$run1_mod3" == "$run2_mod3" ] && [ "$run2_mod3" == "$run3_mod3" ]; then
	echo "Good: module 03 was never deleted."
else
	echo "Bad: the output of module 03 is supposed to stay the same."
	failures=$((failures + 1))
fi

if [ "$run1_mod4" != "$run2_mod4" ] && [ "$run2_mod4" != "$run3_mod4" ]; then
	echo "Good: module 04 re-executed each time."
else
	echo "Bad: module 04 should have been reset."
	failures=$((failures + 1))
fi

if [ -f ${RESTART_DIR}/biolockjComplete ]; then
	echo "Good: with correction, the pipeline completes."
else
	echo "Bad: the pipeline was supposed to complete."
	failures=$((failures + 1))
fi

if [ $failures -eq 0 ]; then
	echo "Basic Restart Test: PASSING"
	exit 0
else
	echo "Basic Restart Test: FAIL, at $failures checkpoints."
	exit 1
fi
