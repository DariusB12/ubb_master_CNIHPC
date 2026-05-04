#!/bin/bash

# --- Configurație ---
#EXE="./main"
#EXE="./main7a"
EXE="./main7b"

NP=4

if [ "$EXE" == "./main" ]; then
    MPIRUN=""
else
    MPIRUN="mpirun -np ${NP}"
fi
#FISIERUL nodes.txt TREBUIE MODIFICAT PT 25 SI 64 DE PROCESE
#MPIRUN="/usr/mpi/gcc/openmpi-1.8.8/bin/mpirun -np ${NP} -hostfile nodes.txt"


M=1000

FILE_A="test1000/fileA.bin"
FILE_B="test1000/fileB.bin"
FILE_C="test1000/fileC.bin"

RUNS=10

sum_read=0
sum_add=0
sum_write=0
sum_total=0

echo "--------------------------------------"

for ((i=1; i<=RUNS; i++))
do
    output=$($MPIRUN $EXE $M $FILE_A $FILE_B $FILE_C)

    t_read=$(echo "$output" | grep "t_reading" | awk '{print $2}')
    t_add=$(echo "$output" | grep "t_addition" | awk '{print $2}')
    t_write=$(echo "$output" | grep "t_writing" | awk '{print $2}')
    t_total=$(echo "$output" | grep "t_total" | awk '{print $2}')

    echo "Rularea $i: Read=${t_read}ms, Mult=${t_add}ms, Write=${t_write}ms, Total=${t_total}ms"

    sum_read=$(echo "$sum_read + $t_read" | bc)
    sum_add=$(echo "$sum_add + $t_add" | bc)
    sum_write=$(echo "$sum_write + $t_write" | bc)
    sum_total=$(echo "$sum_total + $t_total" | bc)
done

avg_read=$(echo "scale=2; $sum_read / $RUNS" | bc)
avg_add=$(echo "scale=2; $sum_add / $RUNS" | bc)
avg_write=$(echo "scale=2; $sum_write / $RUNS" | bc)
avg_total=$(echo "scale=2; $sum_total / $RUNS" | bc)

echo "--------------------------------------"
echo "Media t_reading:    $avg_read ms"
echo "Media t_addition:   $avg_add ms"
echo "Media t_writing:    $avg_write ms"
echo "Media t_total:      $avg_total ms"
echo "--------------------------------------"