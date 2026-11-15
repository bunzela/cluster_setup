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
JUPYTER_PORT=23289      # offered as the default at the prompt
HUB_API_PORT=23291      # configurable-http-proxy REST api, jupyterhub only

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
    echo "Conda env already there, nothing installed: $ENV_NAME"
else
    conda create -n $ENV_NAME python=3.11 -y
    conda activate $ENV_NAME

    # conda first, then pip, so conda does not overwrite pip-installed files
    conda install -c conda-forge mdtraj mdanalysis libnetcdf scikit-learn -y
    pip install rdkit notebook ipywidgets pytraj umap-learn torch fair-esm transformers ipykernel \
                jupyterlab jupyter_server jupyterhub jupyterhub-firstuseauthenticator
    python -m ipykernel install --user --name $ENV_NAME --display-name "Python ($ENV_NAME)"

    echo "Conda env created: $ENV_NAME"
fi

# ------------------------------- jupyterhub -----------------------------------

if [[ -f ~/.jupyter/jupyterhub_config.py ]]; then
    echo "Jupyterhub config already there, nothing changed"
else
    mkdir -p ~/.jupyter
    jupyterhub --generate-config -f ~/.jupyter/jupyterhub_config.py

    cat >> ~/.jupyter/jupyterhub_config.py <<EOF

c.JupyterHub.authenticator_class = 'firstuseauthenticator.FirstUseAuthenticator'
c.Authenticator.allowed_users = {'$USER'}
c.Authenticator.admin_users = {'$USER'}
c.FirstUseAuthenticator.dbm_path = '$HOME/.jupyter/jupyterhub-users.dbm'
c.ConfigurableHTTPProxy.api_url = 'http://127.0.0.1:$HUB_API_PORT'
EOF

    echo "Jupyterhub config written"
fi

# -------------------------------- jupyter.sh ----------------------------------

read -p "Jupyter port [$JUPYTER_PORT]: " PORT
PORT=${PORT:-$JUPYTER_PORT}

if [[ ! "$PORT" =~ ^[0-9]+$ ]] || (( PORT < 1024 || PORT > 65535 )); then
    echo "Not a usable port: $PORT"
    exit 1
fi

cat > ~/bin/jupyter.sh <<EOF
#!/usr/bin/env bash
# written by setup_cluster.sh

rm -f ~/.jupyter/jupyterhub-proxy.pid
pkill -f -u \$(whoami) "jupyterhub|configurable-http-proxy"
jupyter lab --no-browser --port=$PORT
EOF

chmod +x ~/bin/jupyter.sh
echo "Wrote ~/bin/jupyter.sh on port $PORT"

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
