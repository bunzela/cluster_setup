#!/usr/bin/env bash
#
# aizymes.sh
#
# AIzymes setup. Sourced by setup_cluster.sh when AIZYMES=True.

AIZYMES_REPO=https://github.com/bunzela/AIzymes_dev.git
AIZYMES_BRANCH=AIzymes_dev_2025
AIZYMES_DIR=$HOME/bin/AIzymes_dev
BOLTZ_ENV=boltz

# ------------------------------ the repository ---------------------------------

# stores the PAT in plain text in ~/.git-credentials, so create that file
# locked down before git writes a token into it, home is group readable
touch ~/.git-credentials
chmod go= ~/.git-credentials

git config --global credential.helper store

if [[ -d $AIZYMES_DIR ]]; then
    echo "AIzymes already cloned: $AIZYMES_DIR"
else
    echo "Cloning AIzymes, give your GitHub username and a PAT as the password"
    git clone -b $AIZYMES_BRANCH $AIZYMES_REPO $AIZYMES_DIR
fi

# -------------------------------- packages -------------------------------------

conda install -c conda-forge bioconda::mmseqs2 openbabel -y

pip install pandas biopython matplotlib ipywidgets bqplot py3Dmol gemmi mdtraj \
            prody ml_collections tree dm-tree rdkit nbstripout cloudpickle polars \
            "lightning[extra]"

# separate, -U would otherwise upgrade everything beside it
pip install --upgrade MDAnalysis

# last on purpose, the installs above pull numpy 2. Below 1.24, because
# LigandMPNN's vendored openfold uses the np.int alias that 1.24 removed, and
# LigandMPNN itself pins numpy 1.23.
pip install "numpy<1.24" pandas

# ------------------------------- gpu stack -------------------------------------

if [[ "$CLUSTER" == "raven" ]]; then
    BOLTZ_SPEC="boltz[cuda]"
else
    # boltz has no ROCm extra, so this is a CPU build on Viper
    BOLTZ_SPEC="boltz"
fi

echo "Boltz on $CLUSTER: $BOLTZ_SPEC"

# ------------------------------- boltz env -------------------------------------

if conda env list | grep -qw "$BOLTZ_ENV"; then
    echo "Conda env already there: $BOLTZ_ENV"
else
    conda create -n $BOLTZ_ENV python=3.11 -y
    echo "Conda env created: $BOLTZ_ENV"
fi

conda activate $BOLTZ_ENV

conda install -c conda-forge jq openbabel -y
pip install matplotlib gemmi rdkit

if [[ "$CLUSTER" != "raven" ]]; then
    pip install torch torchvision --index-url $ROCM_INDEX
fi

pip install -U "$BOLTZ_SPEC"

conda activate $ENV_NAME

# --------------------------------- bashrc --------------------------------------

AIZYMES_BASHRC=(
    'export PYTHONPATH="$PYTHONPATH:$HOME/bin/AIzymes_dev/src/aizymes"'
)

for line in "${AIZYMES_BASHRC[@]}"; do
    if grep -qxF "$line" ~/.bashrc; then
        echo "Already in bashrc: $line"
    else
        echo "$line" >> ~/.bashrc
        echo "Added to bashrc:   $line"
    fi
done
