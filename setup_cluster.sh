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

USER=${USER:-$(id -un)}   # empty USER would hit all of /u and /ptmp

# ------------------------------ which cluster ---------------------------------

CLUSTER=$(scontrol show config | grep ClusterName | awk '{print $3}')

if [[ "$CLUSTER" != "raven" && "$CLUSTER" != "viper" ]]; then
    echo "Unsupported cluster: $CLUSTER"
    exit 1
fi

echo "Cluster: $CLUSTER"

source "$(dirname "$0")/$CLUSTER.sh"

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
