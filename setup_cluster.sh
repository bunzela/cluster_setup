#!/usr/bin/env bash
#
# setup_cluster.sh
#
#   mkdir -p ~/bin && cd ~/bin
#   git clone https://github.com/bunzela/cluster_setup.git
#   bash cluster_setup/setup_cluster.sh

set -e

# ------------------------------- settings -------------------------------------

AIZYMES=True
ENV_NAME=py311
PORT_MIN=1024
PORT_MAX=65535

USER=$(id -un)

# ------------------------------ which cluster ---------------------------------

CLUSTER=$(scontrol show config | grep ClusterName | awk '{print $3}')

if [[ "$CLUSTER" != "raven" && "$CLUSTER" != "viper" ]]; then
    echo "Unsupported cluster: $CLUSTER"
    exit 1
fi

echo "Cluster: $CLUSTER"

# ------------------------------- permissions ----------------------------------

if getfacl -cp /u/$USER | grep -q '^default:group::r'; then
    echo "Permissions already set, nothing changed"
else
    # make all files in home and ptmp readable for the group
    setfacl -R -m u::rwX,g::rX,o::--- /{u,ptmp}/$USER
    find /{u,ptmp}/$USER -type d -exec setfacl -d -m u::rwx,g::rx,o::--- {} +
    setfacl -b -k ~/.ssh ~/.gnupg; chmod -R go= ~/.ssh ~/.gnupg
    echo "Permissions changed"
fi

# --------------------- modules and python, per cluster ------------------------

if ! type module &>/dev/null; then
    echo "module command not found"
    exit 1
fi

source "$(dirname "$0")/$CLUSTER.sh"

# ----------------------- conda environment, shared ----------------------------

# conda init is not allowed on MPCDF systems, the shell hook replaces it
eval "$(conda shell.bash hook)"

if conda env list | grep -qw "$ENV_NAME"; then
    echo "Conda env already there: $ENV_NAME"
else
    conda create -n $ENV_NAME python=3.11 -y
    echo "Conda env created: $ENV_NAME"
fi

conda activate $ENV_NAME

# Both tools skip whatever is already present, so this also repairs an
# environment left half-installed by an interrupted run.
# conda first, then pip, so conda does not overwrite pip-installed files
conda install -c conda-forge mdtraj mdanalysis libnetcdf scikit-learn -y
pip install rdkit notebook ipywidgets pytraj umap-learn torch fair-esm transformers ipykernel \
            jupyterlab jupyter_server

python -m ipykernel install --user --name $ENV_NAME --display-name "Python ($ENV_NAME)"

# -------------------------------- jupyter.sh ----------------------------------

read -p "Jupyter port ($PORT_MIN-$PORT_MAX): " PORT

if [[ ! "$PORT" =~ ^[0-9]+$ ]] || (( PORT < PORT_MIN || PORT > PORT_MAX )); then
    echo "Not a usable port: $PORT"
    exit 1
fi

cat > ~/jupyter.sh <<EOF
#!/usr/bin/env bash

jupyter lab --no-browser --port=$PORT
EOF

chmod +x ~/jupyter.sh
echo "Wrote ~/jupyter.sh on port $PORT"

# -------------------------------- bashrc --------------------------------------

BASHRC_LINES=(
    'export PYTHONNOUSERSITE=1'
    'eval "$(conda shell.bash hook)"'
    "conda activate $ENV_NAME"
)

for line in "${BASHRC_LINES[@]}"; do
    if grep -qxF "$line" ~/.bashrc; then
        echo "Already in bashrc: $line"
    else
        echo "$line" >> ~/.bashrc
        echo "Added to bashrc:   $line"
    fi
done

# --------------------------------- finish -------------------------------------

source ~/.bashrc
