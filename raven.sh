#!/usr/bin/env bash
#
# raven.sh
#
# Raven modules and python. Sourced by setup_cluster.sh.

PYTHON_MODULE=python-waterboa/2026.07

# load it now, the rest of setup_cluster.sh needs conda
module load $PYTHON_MODULE

MODULES=(
    "module load $PYTHON_MODULE"
)

for line in "${MODULES[@]}"; do
    if grep -qxF "$line" ~/.bashrc; then
        echo "Already in bashrc: $line"
    else
        echo "$line" >> ~/.bashrc
        echo "Added to bashrc:   $line"
    fi
done
