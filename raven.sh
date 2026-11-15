#!/usr/bin/env bash
#
# raven.sh
#
# Raven specifics. Sourced by setup_cluster.sh.

# ------------------------------ load modules ----------------------------------

MODULES=(
    'module load anaconda/3/2023.03'
    'module load amber/24 gcc/12 impi/2021.9'
    'module load cuda/13.0'
)

for line in "${MODULES[@]}"; do
    if grep -qxF "$line" ~/.bashrc; then
        echo "Already in bashrc: $line"
    else
        echo "$line" >> ~/.bashrc
        echo "Added to bashrc:   $line"
    fi
done
