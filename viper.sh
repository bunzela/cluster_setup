#!/usr/bin/env bash
#
# viper.sh
#
# Viper modules and python. Sourced by setup_cluster.sh.

PYTHON_MODULE=python-waterboa/2026.07

# load it now, the rest of setup_cluster.sh needs conda
module load $PYTHON_MODULE

# amber/26 is the first Amber with HIP support, so it is the first one available
# on Viper-GPU, and it carries AmberTools (tleap, sander, cpptraj) and pmemd in
# one module. It pulls gcc/14, rocm/7.2 and openmpi/5.0 with it.
MODULES=(
    "module load $PYTHON_MODULE"
    'module load amber/26'
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
