#!/bin/bash
# Centralized Case Manager

CASE_DIR=$(pwd)
cd "$CASE_DIR" || exit 1

. $WM_PROJECT_DIR/bin/tools/RunFunctions
. ${WM_PROJECT_DIR:?}/bin/tools/CleanFunctions

echo
echo "Usage: ./run.sh [OPTION]"
echo "  -clean       Just clean the case"
echo "  -mesh        Clean and generate mesh ONLY"
echo "  -init        Clean and initialize U/p/T (no solver run)"
echo "  -cont        Continue solving"
echo "  -new         Clean and run from 0 (uses existing mesh)"
echo

# --- 1. Option Selector by ARG1 ---
case "$1" in
    -clean)
        echo "Cleaning case..."
        pkill foamRun
        pkill  gnuplot
        rm -rf postProcessing processor* dynamicCode log.*
        rm -rf $(foamListTimes -noZero)
        if [ -d 0.orig ]; then
            rm -rf 0
            cp -r 0.orig 0
        fi
        exit 0
        ;;

    -mesh)
        echo "Cleaning and generating mesh..."
        pkill foamRun
        pkill  gnuplot
        rm -rf postProcessing processor* dynamicCode log.*
        rm -rf $(foamListTimes -noZero)
        if [ -d 0.orig ]; then
            rm -rf 0
            cp -r 0.orig 0
        fi
        runApplication blockMesh
        runApplication extrudeMesh
        checkMesh 2>&1 | tee log.checkMesh
        exit 0
        ;;

    -init)
        echo "Cleaning and initializing fields..."
        pkill foamRun
        pkill  gnuplot
        rm -rf postProcessing processor* dynamicCode log.initT log.foamRun log.decomposePar log.potentialFoam
        rm -rf $(foamListTimes -noZero)
        if [ -d 0.orig ]; then
            rm -rf 0
            cp -r 0.orig 0
        fi
        potentialFoam -writep -writePhi 2>&1 | tee log.potentialFoam
		ORIG_END=$(grep "endTime" system/controlDict | grep -oE '[0-9.]+' | head -1)
		sed -i "0,/endTime/s/endTime.*/endTime 1;/" system/controlDict
        foamRun > log.initT
        sed -i "0,/endTime/s/endTime.*/endTime $ORIG_END;/" system/controlDict
        echo "Initialization complete. Verify in ParaView."
        exit 0
        ;;

    -new)
        echo "Cleaning and starting new run (skipping mesh)..."
		pkill foamRun
        pkill  gnuplot
        rm -rf postProcessing processor* dynamicCode log.foamRun log.decomposePar log.initT log.potentialFoam
        rm -rf $(foamListTimes -noZero)
        latest_res="0"
        runApplication decomposePar -latestTime
        runParallel foamRun &
        while [ $(grep -c "Execution" log.foamRun | wc -l) -lt 5 ]; do
            echo "Waiting for 5 iterations..."
            sleep 3
        done
        echo "Launching Gnuplot monitor..."
        gnuplot -c ~/OpenFOAM/scripts/monitor.gp &
        ;;

	-cont)
        echo "Continuing simulation..."
        latest_res=$(ls -v postProcessing/residuals/ 2>/dev/null | tail -n 1)
        latest_res=${latest_res:-0}
        rm log.decomposePar log.foamRun
        runApplication decomposePar -latestTime
        runParallel foamRun &
        while [ $(grep "Execution" log.foamRun | wc -l) -lt 5 ]; do
            echo "Waiting for 5 iterations..."
            sleep 3
        done
        echo "Launching Gnuplot monitor..."
        gnuplot -c ~/OpenFOAM/scripts/monitor.gp &
        ;;
    *)
esac

