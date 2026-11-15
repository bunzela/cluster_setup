#!/usr/bin/env bash
#
# viper.sh
#
# Viper specifics. Sourced by setup_cluster.sh.

# ------------------------------ load modules ----------------------------------

MODULES=(
    'module load python-waterboa/2026.07'
)

for line in "${MODULES[@]}"; do
    if grep -qxF "$line" ~/.bashrc; then
        echo "Already in bashrc: $line"
    else
        echo "$line" >> ~/.bashrc
        echo "Added to bashrc:   $line"
    fi
done
