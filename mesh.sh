#!/bin/sh
cd ${0%/*} || exit 1    # Run from this directory

. $WM_PROJECT_DIR/bin/tools/RunFunctions
. ${WM_PROJECT_DIR:?}/bin/tools/CleanFunctions

rm log.blockMesh
rm log.extrudeMesh
rm log.checkMesh
rm -rf postProcessing
rm -rf $(foamListTimes -noZero)
rm -rf processor*
rm -f log.decomposePar

runApplication blockMesh
runApplication extrudeMesh

#runApplication checkMesh
#cat log.checkMesh
checkMesh 2>&1 | tee -a log.checkMesh

#------------------------------------------------------------------------------
