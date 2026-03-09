#!/bin/sh
cd ${0%/*} || exit 1    # Run from this directory

. $WM_PROJECT_DIR/bin/tools/RunFunctions
. ${WM_PROJECT_DIR:?}/bin/tools/CleanFunctions


# ------------- run the solver ------------------#
# fresh start if -c not iven
if [ "$1" != "-c" ]; then
    echo "Fresh start: Cleaning case..."
	rm -rf postProcessing
	rm -rf $(foamListTimes -noZero)
	rm -rf processor*
	rm -f log.decomposePar
	runApplication decomposePar
fi
rm -f log.foamRun
runParallel foamRun &

# ---------------- launch monitor -----------------#

# get latest residuals file
if [ "$1" = "-c" ]; then
	latest_res=$(ls -v postProcessing/residuals/ | tail -n 1)
else
	latest_res="0"
fi
res_file="postProcessing/residuals/${latest_res}/residuals.dat"

echo "latest residuals file: ${latest_res}"
echo "\nWaiting for solver to initialize..."

# Loop until file exists and has 12 lines (2 header + 10 data)
while [ ! -f "$res_file" ] || [ $(wc -l < "$res_file") -lt 4 ]
do
    if [ -f "$res_file" ]; then
        LINES=$(wc -l < "$res_file")
        # %s is a string placeholder, \r is the carriage return
        echo "Current iterations: $((LINES-2))"
    else
        echo "Waiting for file creation...   \r"
    fi
    sleep 6
done

gnuplot ~/scripts/myFoamMonitor.gp &


#------------------------------------------------------------------------------
 
