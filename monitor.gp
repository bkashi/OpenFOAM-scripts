# ==============================================================================
# OpenFOAM Dashboard Monitor
# ==============================================================================
# Description:
#    A real-time Gnuplot dashboard for monitoring OpenFOAM simulations.
#
# Key Features:
#    - Dynamic Probe Discovery: Automatically detects all probe folders in 
#      'postProcessing/' (excluding residuals).
#    - Live Stats: Displays residuals on the left Y-axis and normalized probe 
#      values (p, U, T) on the right Y-axis.
#    - Convergence Tracking: Calculates % change for pressure and temperature 
#      relative to the last c_iter=500 iterations.
#    - Plots the last 1000 iterations, unless number given as rgument.
#
# Hotkeys:
#    [q] Quit Monitor | [K] Kill foamRun | [1]-[5] Refresh rate | [r] Refresh
# ==============================================================================

# ---------- define macros -----------
set macro
quit = "system('pkill gnuplot')"
killFoam = "system('pkill foamRun')"
# Macro to evaluate the dynamically built plot string
runPlot = "eval('plot '.plot_string)"


# --------- set key bindings -----------
refresh = 2
bind "q" "@quit"
bind "K" "@killFoam"
bind "1" "refresh=1"
bind "2" "refresh=2"
bind "3" "refresh=5"
bind "4" "refresh=10"
bind "5" "refresh=30"


# --------- define consts. -------------
# number of iterations to plot
if (exists("ARG1") && strlen(ARG1) > 0) { n_iter = ARG1."" } else { n_iter = "1000" }

# get latest residual file
latest_res = system("ls -v postProcessing/residuals/ 2>/dev/null | tail -n 1")
# find all existing probe directories (excluding residuals)
probe_list = system("ls -1 postProcessing/ 2>/dev/null | grep -v 'residuals' || echo ''")

# get residual columns
res_file_header = system("head -n 2 postProcessing/residuals/0/residuals.dat | tail -n 1")
n_res_cols = words(res_file_header) - 2; print n_res_cols
array res_headers[10]
do for [i=1:n_res_cols] {  	res_headers[i] = word(res_file_header, i+2)." res."  } ; print "Plotting residuals:", res_headers

# get static info
case = system("pwd")
start = system("grep '^Time' log.blockMesh 2>/dev/null | cut -c 10-")
nProcs = system("grep '^nProcs' log.foamRun 2>/dev/null | cut -c 9-")
nCells = system("grep 'cells:' log.checkMesh 2>/dev/null | cut -c 22-")

s = 2  # set number of entries to skip 
c_iter = 500; # set number of iterations for convergence calc.


# ------------------ setup figure ------------------------
set object 1 rectangle from screen 0,0 to screen 1,1 behind fillcolor rgb "#333333" fillstyle solid 1.0
set object 2 rectangle from screen 0.81,0.81 to screen 0.99,0.97 behind fillcolor rgb "black" fillstyle solid 1.0
set object 3 rectangle from screen 0.81,0.61 to screen 0.99,0.77 behind fillcolor rgb "black" fillstyle solid 1.0
set object 4 rectangle from screen 0.0,0.0 to screen 1,0.04 behind fillcolor rgb "black" fillstyle solid 1.0
set border lc rgb "white"
set key tc rgb "white" outside bottom center horizontal maxrows 3 spacing 1.4 samplen 2
set key box lc rgb "white"
set grid
set term qt title "OpenFOAM Dashboard" size 1920,950 font ",14" noenhanced
set size 0.76, 0.9
set origin 0.02, 0.08
set ytics nomirror tc rgb "white"
set ylabel "Residuals" tc rgb "white" font ",16"
set logscale y
set format y "%.0e"
set y2tics tc rgb "white"
set y2label "Normalized Probes" tc rgb "white" font ",16"
set y2range [0:1.1] 
unset logscale y2


# ----------------- print static info -------------------
set label 101 "Started............. ".start at screen 0.82, 0.945 tc rgb "white" font "Arial,16"
set label 102 "Cells.................".nCells at screen 0.82, 0.695 tc rgb "white" font "Arial,16"
set label 103 "Processes........".nProcs at screen 0.82, 0.745 tc rgb "white" font "Arial,16"
help = "[q] - quit monitor   [K] - kill foamRun   [1]...[5] - rate   [r] - refresh"
set label 198 help at screen 0.02, 0.02 tc rgb "cyan" font "Arial,12"
set label 199 case at screen 0.99,0.02 right tc rgb "magenta" font ",12"


#--------------------  Main Loop ----------------------#
while (1) { 
	current_time = system("date +%H:%M:%S")
	  
	# Suppressed error check: tries parallel first, then serial
	last_save = system("foamListTimes -latestTime -processor 2>/dev/null || foamListTimes -latestTime 2>/dev/null || echo 'none'")

	set label 110 "Updated........... ".current_time at screen 0.82, 0.895 tc rgb "white" font "Arial,16"
	set label 111 "Refresh............ ".refresh.'s' at screen 0.82, 0.645 tc rgb "white" font "Arial,16"
	set label 112 "Last save..........".last_save at screen 0.82, 0.845 tc rgb "white" font "Arial,16"

	# init. plot command with 1st residual
	plot_string = "'< tail -n '.n_iter.' postProcessing/residuals/'.latest_res.'/residuals.dat' skip s u 1:2 axes x1y1 w l lw 2 dt 2 title '".res_headers[1]."', "

	# add more residuals to plot string
    do for [i=2:n_res_cols-1] {
        plot_string = plot_string."'' skip s u 1:".sprintf("%d", i+1)." axes x1y1 w l lw 2 dt 2 title '".res_headers[i]."', "
	}

	# add last residual to plot string
	plot_string = plot_string."'' skip s u 1:".sprintf("%d", n_res_cols+1)." axes x1y1 w l lw 2 dt 2 title '".res_headers[n_res_cols]."' "

    # Loop through found probe directories
    do for [probe in probe_list] {
        latest_time = system("ls -v postProcessing/".probe."/ 2>/dev/null | tail -n 1")
        path = "postProcessing/".probe."/".latest_time."/"
        
        # Process Pressure (p)
        if (system("test -e ".path."p && echo 1 || echo 0") == 1) {
            stats '< tail -n '.n_iter.' '.path.'p' skip s u 2 name 'p_'.probe nooutput
            last_val = system("tail -n 1 ".path."p 2>/dev/null | awk '{print $2}'")
            prev_val = system("tail -n ".c_iter." ".path."p 2>/dev/null | head -n 1 | awk '{print $2}'")
            conv = (real(prev_val) != 0) ? sprintf("%.1f", (last_val - prev_val)/prev_val * 100) : "..."
            plot_string = plot_string . ", '< tail -n '.n_iter.' ".path."p' skip s u 1:($2/p_".probe."_max) axes x1y2 w l lw 3 title 'p ".probe." (".conv."%)'"
        }
          
        # Process Velocity (U)
        if (system("test -e ".path."U && echo 1 || echo 0") == 1) {
            stats '< tail -n '.n_iter.' '.path.'U' skip s u (($2**2+$3**2+$4**2)**0.5) "%lf (%lf %lf %lf)" name 'U_'.probe nooutput
            # Calculate magnitude convergence for U (L2 norm)
            last_U = system("tail -n 1 ".path."U 2>/dev/null | awk -F'[()]' '{print $2}' | awk '{print sqrt($1*$1+$2*$2+$3*$3)}'")
            prev_U = system("tail -n ".c_iter." ".path."U 2>/dev/null | head -n 1 | awk -F'[()]' '{print $2}' | awk '{print sqrt($1*$1+$2*$2+$3*$3)}'")
            conv_U = (real(prev_U) != 0) ? sprintf("%.1f", (last_U - prev_U)/prev_U * 100) : "..."
            plot_string = plot_string . ", '< tail -n '.n_iter.' ".path."U' skip s u 1:((($2**2+$3**2+$4**2)**0.5)/U_".probe."_max) \"%lf (%lf %lf %lf)\" axes x1y2 w l lw 3 title 'U ".probe." (".conv_U."%)'"
        }
          
        # Process Temperature (T)
        if (system("test -e ".path."T && echo 1 || echo 0") == 1) {
            stats '< tail -n '.n_iter.' '.path.'T' skip s u 2 name 'T_'.probe nooutput
            last_val = system("tail -n 1 ".path."T 2>/dev/null | awk '{print $2}'")
            prev_val = system("tail -n ".c_iter." ".path."T 2>/dev/null | head -n 1 | awk '{print $2}'")
            conv = (real(prev_val) != 0) ? sprintf("%.1f", (last_val - prev_val)/prev_val * 100) : "..."
            plot_string = plot_string . ", '< tail -n '.n_iter.' ".path."T' skip s u 1:($2/T_".probe."_max) axes x1y2 w l lw 3 title 'T ".probe." (".conv."%)'"
        }
	}
    eval('plot '.plot_string)
    pause refresh
}

