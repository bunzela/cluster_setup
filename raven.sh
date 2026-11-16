#!/usr/bin/env bash
#
# raven.sh
#
# Raven modules and python. Sourced by setup_cluster.sh.

PYTHON_MODULE=python-waterboa/2026.07

# load the python module now, the rest of setup_cluster.sh needs conda
module load $PYTHON_MODULE

MODULES=(
    "module load $PYTHON_MODULE"
    'module load amber/24 gcc/12 impi/2021.9'
    'module load cuda/13.0'
    # runs containers, e.g. Rosetta from ~/bin/rosetta.sif
    'module load apptainer'
)

for line in "${MODULES[@]}"; do
    if grep -qxF "$line" ~/.bashrc; then
        echo "Already in bashrc: $line"
    else
        echo "$line" >> ~/.bashrc
        echo "Added to bashrc:   $line"
    fi
done
