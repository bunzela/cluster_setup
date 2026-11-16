#!/usr/bin/env bash
#
# aizymes.sh
#
# AIzymes setup. Sourced by setup_cluster.sh when AIZYMES=True.

AIZYMES_REPO=https://github.com/bunzela/AIzymes_dev.git
AIZYMES_BRANCH=AIzymes_dev_2025
AIZYMES_DIR=$HOME/bin/AIzymes_dev
LIGANDMPNN_REPO=https://github.com/dauparas/LigandMPNN.git
LIGANDMPNN_DIR=$HOME/bin/LigandMPNN
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

# last on purpose, the installs above pull numpy 2. Not below 1.24 either:
# scipy needs >= 1.26.4 and fails to import without numpy.exceptions, so
# LigandMPNN's vendored openfold is patched instead of holding numpy back.
pip install "numpy<2.0" pandas

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

# ------------------------------- ligandmpnn ------------------------------------

if [[ -d $LIGANDMPNN_DIR ]]; then
    echo "LigandMPNN already cloned: $LIGANDMPNN_DIR"
else
    git clone $LIGANDMPNN_REPO $LIGANDMPNN_DIR
fi

# LigandMPNN vendors openfold, which uses the numpy aliases removed in 1.24.
# numpy cannot go below that, scipy needs 1.26.4, so the aliases are rewritten
# on install. Same command LigandMPNN_check prints. Upstream has not fixed this,
# so this runs again after a pull. grep finds nothing once patched, and the
# pipeline swallows its exit status, so the step is safe to repeat.
grep -rl "np\.int\b\|np\.float\b\|np\.bool\b\|np\.complex\b\|np\.object\b\|np\.str\b" \
     $LIGANDMPNN_DIR/openfold/ | xargs -r sed -i \
's/np\.int\b/int/g;
s/np\.float\b/float/g;
s/np\.bool\b/bool/g;
s/np\.complex\b/complex/g;
s/np\.object\b/object/g;
s/np\.str\b/str/g'

if [[ -d $LIGANDMPNN_DIR/model_params ]]; then
    echo "LigandMPNN weights already there: $LIGANDMPNN_DIR/model_params"
else
    (cd $LIGANDMPNN_DIR && bash get_model_params.sh ./model_params)
fi

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
