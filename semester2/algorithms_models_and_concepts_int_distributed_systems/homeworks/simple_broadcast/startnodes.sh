#!/bin/bash

# verify arguments
if [ "$#" -ne 3 ]; then
    echo "Usage: ./startnodes.sh <config_file> <first_index> <last_index>"
    exit 1
fi

CONFIG_FILE=$1
FIRST=$2
LAST=$3

echo "Starting nodes from index $FIRST to $LAST..."

for (( i=$FIRST; i<=$LAST; i++ ))
do
    # run each node in background
    python3 bcastnode.py "$CONFIG_FILE" "$i" &
    echo "Node $i started."
done

# wait for all the brackground processes to finish
wait
echo "All nodes have finished their work."