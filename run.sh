#!/bin/bash
# Centralized Case Manager
# Usage: ./run.sh         (Continue)
#        ./run.sh -new    (Clean + Restart)
#        ./run.sh -mesh   (Clean + Mesh + Restart)

# Support for hard links: operate in the current working directory
CASE_DIR=$(pwd)
cd "$CASE_DIR" || exit 1

. $WM_PROJECT_DIR/bin/tools/RunFunctions
. ${WM_PROJECT_DIR:?}/bin/tools/CleanFunctions


# --- 1. Exclusive Setup Block ---
case "$1" in
    -new|-mesh)
        echo "Stopping existing processes and cleaning case..."
        killall -q foamRun
        killall -q gnuplot
        sleep 1

        # Clean case
        rm -rf postProcessing processor* log.decomposePar log.foamRun
        rm -rf $(foamListTimes -noZero)
		rm -rf 0
		cp -r 0.orig 0
		
        if [ "$1" == "-mesh" ]; then
            echo "Generating mesh..."
            rm log.blockMesh log.extrudeMesh log.checkMesh
            runApplication blockMesh
            runApplication extrudeMesh
            checkMesh 2>&1 | tee -a log.checkMesh
        fi

        echo "Decomposing case..."
        runApplication decomposePar -latestTime
        latest_res="0"
        ;;

    *)
        # Default/Continue: Find the latest residuals directory
        echo "Continuing simulation..."
		sleep 1
		echo "."
		sleep 1
		echo ".."
		sleep 1
		echo "..."
        latest_res=$(ls -v postProcessing/residuals/ 2>/dev/null | tail -n 1)
        latest_res=${latest_res:-0}
        echo $latest_res
        ;;
esac


# --- 2. Launch Solver ---
echo "Starting foamRun in parallel..."
mv log.foamRun log.foamRun.latest_res
runParallel foamRun &


# --- 3. Monitor Initialization ---
res_file="postProcessing/residuals/${latest_res}/residuals.dat"

while [ ! -f "$res_file" ] || [ $(wc -l < "$res_file") -lt 14 ]
do
    if [ -f "$res_file" ]; then
        echo -ne "Current iterations: $(($(wc -l < "$res_file")-2))\r"
    else
        echo -ne "Waiting for solver output... \r"
    fi
    sleep 2
done
echo -e "\nSolver ready."

# Launch Gnuplot Dashboard
gnuplot -c ~/OpenFOAM/scripts/monitor.gp &
