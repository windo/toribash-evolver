#!/bin/sh

f=$1

gnuplot -persist << EOF
plot \
	"$1" using(\$1) w line t 'max', \
	"$1" using(\$2) w line t '90th %', \
	"$1" using(\$3) w line t '75th %', \
	"$1" using(\$4) w line t '50th %', \
	"$1" using(\$5) w line t '25th %', \
	"$1" using(\$6) w line t 'avg'
EOF
