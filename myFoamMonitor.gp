
# define macros
set macro
quit = "system('pkill gnuplot')"
killFoam = "system('pkill foamRun')"


# number of iterations to plot
if (exists("ARG1") && strlen(ARG1) > 0) {
    n_iter = ARG1.""
} else {
    n_iter = "1000"
}


# set key bindngs
refresh = 5
bind "q" "@quit"
bind "K" "@killFoam"
bind "1" "refresh=1"
bind "2" "refresh=2"
bind "3" "refresh=5"
bind "4" "refresh=10"
bind "5" "refresh=30"


# get latest residual & probe files
latest_res = system("ls -v postProcessing/residuals/ | tail -n 1")
latest_inlet_probe = system("ls -v postProcessing/inletProbes/ | tail -n 1")
latest_outlet_probe = system("ls -v postProcessing/outletProbes/ | tail -n 1")


# get static info
case = system("pwd")
start = system("grep '^Time' log.blockMesh | cut -c 10-")
nProcs = system("grep '^nProcs' log.foamRun | cut -c 9-")
nCells = system("grep 'cells:' log.checkMesh | cut -c 22-")


# setup figure
set object 1 rectangle from screen 0,0 to screen 1,1 behind fillcolor rgb "#333333" fillstyle solid 1.0
set border lc rgb "white"
set key tc rgb "white" outside bottom center horizontal maxrows 3 spacing 1.4 samplen 2
set key box lc rgb "white"
set grid
set term qt title "OpenFOAM Dashboard" size 1400,900 font ",14" noenhanced
set size 0.8, 0.93
set origin 0.01, 0.07
set ytics nomirror tc rgb "white"
set ylabel "Residuals" tc rgb "white" font ",16"
set logscale y
set format y "%.0e"
set y2tics tc rgb "white"
set y2label "Normalized Probes" tc rgb "white" font ",16"
set y2range [0:1.1] 
unset logscale y2
set arrow 1 from screen 0, 0.04 to screen 1, 0.04 nohead lc rgb "white" lw 2
set arrow 2 from screen 0.8, 0.04 to screen 0.8, 1 nohead lc rgb "white" lw 2


s = 2  # set number of entries to skip 
c_iter = 500;  # set number of iterations for convergence calc.


# print static info
set label 101 "Started............. ".start at screen 0.82, 0.96 tc rgb "yellow" font "Arial,16"
set label 102 "Cells.................".nCells at screen 0.82, 0.81 tc rgb "yellow" font "Arial,16"
set label 103 "Processes........".nProcs at screen 0.82, 0.86 tc rgb "yellow" font "Arial,16"
help = "[q] - quit monitor     [K] - kill foamRun      [1]...[5] - refresh rate"
set label 198 help at screen 0.02, 0.02 tc rgb "cyan" font "Arial,16"
set label 199 case at screen 0.99,0.02 right tc rgb "magenta" font ",16"


		
#--------------------  Main Loop ----------------------#

# test if data exists
if (system("test -e postProcessing/residuals/0/residuals.dat && echo 1 || echo 0") == 1) {
	while (1) { 

		# make strings to display live info
		current_time = system("date +%H:%M:%S")
		set label 110 "Updated........... ".current_time at screen 0.82, 0.91 tc rgb "yellow" font "Arial,16"
		set label 111 "Refresh............ ".refresh.'s' at screen 0.82, 0.76 tc rgb "yellow" font "Arial,16"

		# find max. values for probes
		stats '< tail -n '.n_iter.' postProcessing/inletProbes/'.latest_inlet_probe.'/p'  skip s u 2 name 'p' nooutput
		stats '< tail -n '.n_iter.' postProcessing/inletProbes/'.latest_inlet_probe.'/U'  skip s u (($2**2+$3**2+$4**2)**0.5) "%lf (%lf %lf %lf)" name 'Umag' nooutput
		stats '< tail -n '.n_iter.' postProcessing/outletProbes/'.latest_outlet_probe.'/T' skip s u 2 name 'Tout' nooutput
		stats '< tail -n '.n_iter.' postProcessing/inletProbes/'.latest_inlet_probe.'/T' skip s u 2 name 'Tin' nooutput

		# calc. inlet T convergence in last n_iter iters. in %
		if (real(system("wc -l postProcessing/inletProbes/".latest_inlet_probe."/T | awk '{print $1}'") > c_iter+3)) {
			last_T = system("tail -n 1 postProcessing/inletProbes/".latest_inlet_probe."/T | awk '{print $2}'")
			prev_T = system("tail -n ".c_iter." postProcessing/inletProbes/".latest_inlet_probe."/T | head -n 1 | awk '{print $2}'")
			dTin = sprintf("%.1f", (last_T - prev_T)/prev_T * 100 )  # percentage of change in last 500 iterations
		} else {
			dTin = "..."
		}
		
		# calc. outlet T convergence in last n_iter iters. in %
		if (real(system("wc -l postProcessing/outletProbes/".latest_outlet_probe."/T | awk '{print $1}'") > c_iter+3)) {
			last_T = system("tail -n 1 postProcessing/outletProbes/".latest_outlet_probe."/T | awk '{print $2}'")
			prev_T = system("tail -n ".c_iter." postProcessing/outletProbes/".latest_outlet_probe."/T | head -n 1 | awk '{print $2}'")
			dTout = sprintf("%.1f", (last_T - prev_T)/prev_T * 100 )  # percentage of change in last 500 iterations
		} else {
			dTout = "..."
		}
		
		# calc. inlet p convergence in last n_iter iters. in % 
		if (real(system("wc -l postProcessing/outletProbes/".latest_outlet_probe."/T | awk '{print $1}'") > c_iter+3)) {
			last_p = system("tail -n 1 postProcessing/inletProbes/".latest_inlet_probe."/p | awk '{print $2}'")
			prev_p = system("tail -n ".c_iter." postProcessing/inletProbes/".latest_inlet_probe."/p | head -n 1 | awk '{print $2}'")
			dp = sprintf("%.1f", (last_p - prev_p)/prev_p * 100 )  # percentage of change in last 500 iterations
		} else {
			dp = "..."
		}
		
		# plot all
		plot '< tail -n '.n_iter.' postProcessing/residuals/'.latest_res.'/residuals.dat' \
			    skip s u 1:2 axes x1y1 w l lw 2 dt 2 title 'Ux Res', \
		     '' skip s u 1:3 axes x1y1 w l lw 2 dt 2 title 'Uy Res', \
		     '' skip s u 1:5 axes x1y1 w l lw 2 dt 2 title 'p Res', \
		     '' skip s u 1:6 axes x1y1 w l lw 2 dt 2 title 'T Res', \
		     '< tail -n '.n_iter.' postProcessing/inletProbes/'.latest_inlet_probe.'/p'  skip s u 1:($2/p_max) axes x1y2 w l lw 3 title 'p Inlet ('.dp.'%)', \
		     '< tail -n '.n_iter.' postProcessing/inletProbes/'.latest_inlet_probe.'/U'  skip s u 1:((($2**2+$3**2+$4**2)**0.5)/Umag_max) "%lf (%lf %lf %lf)" axes x1y2 w l lw 3 title 'U Inlet', \
		     '< tail -n '.n_iter.' postProcessing/outletProbes/'.latest_outlet_probe.'/T' skip s u 1:($2/Tout_max) axes x1y2 w l lw 3 title 'T Outlet ('.dTout.'%)', \
		     '< tail -n '.n_iter.' postProcessing/inletProbes/'.latest_inlet_probe.'/T' skip s u 1:($2/Tin_max) axes x1y2 w l lw 3 lc rgb "grey" title 'T inlet ('.dTin.'%)'
		pause refresh
	}
}

		     
