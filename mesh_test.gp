
# --- Cases to Plot ----
caseI = 'mesh2'
caseII = 'mesh3'
caseIII = 'mesh4'


# --- Constants ---
nu = 1e-6  # as set in transport properties
alpha = 1.667e-8  # as set in function object for scalar transport
d = 0.1  # from blockMeshDict
u = 0.015  # from 0/U then scaled from the inlet to the pipe (D/d)^2 = 16
dTdy = 3000  # fixedGradient in 0/T
C = 4*alpha*dTdy/(d*u)  # const. for later bulk temp. calc.


# --- Get Data Path ---
latestI = system("foamListTimes -case ".caseI." -latestTime")
latestII = system("foamListTimes -case ".caseII." -latestTime")
latestIII = system("foamListTimes -case ".caseIII." -latestTime")
print "Mesh I, II, III Times: ", latestI, latestII, latestIII

 
# --- Setup Multiplot Terminal ---
set term qt size 1400,600 title "Mesh Independence Test: Re=1500, Pr=60"
set multiplot layout 1, 2 title "Mesh Independence Test (Re=1500, Pr=60)" font ",14"


# --- Figure 1: Nusselt Number (Left) ---
set title "Nusselt Number" font ",12"
set xlabel "x/d"
set ylabel "Nu"
set grid
set yrange [0:]
set key top right
plot	'./'.caseI.'/postProcessing/sampleDict/'.latestI.'/wallData.xy' skip 2 using ($1/d) : (dTdy*d / ($2 - $1*C)) with lines lw 3 dt 1 lc rgb "green" title 'Mesh I', \
	 	'./'.caseII.'/postProcessing/sampleDict/'.latestII.'/wallData.xy' skip 2 using ($1/d) : (dTdy*d / ($2 - $1*C)) with lines lw 3 dt 2 lc rgb "blue" title 'Mesh II', \
		'./'.caseIII.'/postProcessing/sampleDict/'.latestIII.'/wallData.xy' skip 2 using ($1/d) : (dTdy*d / ($2 - $1*C)) with lines lw 3 dt 3 lc rgb "red" title 'Mesh III'

	 
# --- Figure 2: Skin Friction Coefficient (Right) ---
set title "Friction Factor"
set xlabel "x/d"
set ylabel "Cf"
set grid
set autoscale y
set key top right
plot	 './'.caseI.'/postProcessing/sampleDict/'.latestI.'/wallData.xy' skip 2 using ($1/d) : (-nu*$6/(0.5*u*u)) with lines lw 3 dt 1 lc rgb "green" title 'Mesh I', \
		 './'.caseII.'/postProcessing/sampleDict/'.latestII.'/wallData.xy' skip 2 using ($1/d) : (-nu*$6/(0.5*u*u)) with lines lw 3 dt 2 lc rgb "blue" title 'Mesh II', \
		 './'.caseIII.'/postProcessing/sampleDict/'.latestIII.'/wallData.xy' skip 2 using ($1/d) : (-nu*$6/(0.5*u*u)) with lines lw 3 dt 3 lc rgb "red" title 'Mesh III'
	 
unset multiplot
