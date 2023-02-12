
# How to use:
# gnuplot sprott.plt

reset

set encoding utf8
set terminal pngcairo enhanced size 1200,900 font 'Sans,20'

set output "Sprott-A-XY.png"
set xlabel "x"
set ylabel "y"
plot "Chaos.txt" u 1:2 w l title "Sprott A (x,y)"

set output "Sprott-A-XZ.png"
set xlabel "x"
set ylabel "z"
plot "Chaos.txt" u 1:3 w l title "Sprott A (x,z)"

set output "Sprott-A-YZ.png"
set xlabel "y"
set ylabel "z"
plot "Chaos.txt" u 2:3 w l title "Sprott A (y,z)"
