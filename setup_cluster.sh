#!/usr/bin/env bash
#
# setup_cluster.sh
#
# Streamlined environment setup for the MPCDF clusters.
#
#   mkdir -p ~/bin && cd ~/bin
#   git clone https://github.com/bunzela/cluster_setup.git
#   bash cluster_setup/setup_cluster.sh

set -euo pipefail

# ==============================================================================
#  DEFAULT SETTINGS
# ==============================================================================

AIZYMES="${AIZYMES:-True}"                  # install AIzymes

SUPPORTED_CLUSTERS=("raven" "viper")        # anything else is an error

SHARE_DIRS_TEMPLATE=("/u" "/ptmp")          # made group readable, per user

# ==============================================================================
#  Internals
# ==============================================================================

USER="${USER:-$(id -un)}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CLUSTER=""
SHARE_DIRS=()

# ----------------------------------------------------------------------- output

if [[ -t 1 ]]; then
    C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'; C_DIM=$'\033[2m'
    C_RED=$'\033[31m'; C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'; C_BLUE=$'\033[34m'
else
    C_RESET=''; C_BOLD=''; C_DIM=''
    C_RED=''; C_GREEN=''; C_YELLOW=''; C_BLUE=''
fi

info() { printf '%s==>%s %s\n' "$C_BLUE$C_BOLD" "$C_RESET" "$*"; }
ok()   { printf '%s  ok%s %s\n'  "$C_GREEN"  "$C_RESET" "$*"; }
warn() { printf '%swarn%s %s\n'  "$C_YELLOW" "$C_RESET" "$*" >&2; }
dim()  { printf '%s     %s%s\n'  "$C_DIM" "$*" "$C_RESET"; }
die()  { printf '%serror%s %s\n' "$C_RED$C_BOLD" "$C_RESET" "$*" >&2; exit 1; }

have() { command -v "$1" >/dev/null 2>&1; }

is_true() {
    case "${1,,}" in
        true | t | yes | y | on | 1) return 0 ;;
        *) return 1 ;;
    esac
}

# ==============================================================================
#  1. Which cluster are we on
# ==============================================================================

detect_cluster() {
    have scontrol || die "scontrol not found, this does not look like a SLURM cluster"

    local raw name
    raw="$(scontrol show config 2>/dev/null | grep -m1 'ClusterName' || true)"
    [[ -n "$raw" ]] || die "could not read ClusterName from 'scontrol show config'"

    name="${raw#*=}"
    name="$(tr -d '[:space:]' <<<"$name")"
    name="${name,,}"

    [[ -n "$name" ]] || die "ClusterName is empty in 'scontrol show config'"

    local known
    for known in "${SUPPORTED_CLUSTERS[@]}"; do
        if [[ "$name" == "$known" ]]; then
            CLUSTER="$name"
            return 0
        fi
    done

    die "unsupported cluster '$name', expected one of ${SUPPORTED_CLUSTERS[*]}"
}

load_cluster_profile() {
    local profile="$SCRIPT_DIR/$CLUSTER.sh"

    [[ -f "$profile" ]] || die "no profile found at $CLUSTER.sh"
    # shellcheck source=/dev/null
    source "$profile"
}

# ==============================================================================
#  2. Make home and scratch readable for the group
# ==============================================================================

collect_share_dirs() {
    SHARE_DIRS=()

    local root dir
    for root in "${SHARE_DIRS_TEMPLATE[@]}"; do
        dir="$root/$USER"
        if [[ -d "$dir" ]]; then
            SHARE_DIRS+=("$dir")
        else
            warn "$dir does not exist, skipping"
        fi
    done

    [[ ${#SHARE_DIRS[@]} -gt 0 ]] || die "none of ${SHARE_DIRS_TEMPLATE[*]}/$USER exist"
}

# True when every directory already grants group read and carries the default
# ACL, which is how we know this ran before.
permissions_already_shared() {
    local dir acl

    for dir in "${SHARE_DIRS[@]}"; do
        acl="$(getfacl -c "$dir" 2>/dev/null || true)"
        grep -q '^group::r'         <<<"$acl" || return 1
        grep -q '^default:group::r' <<<"$acl" || return 1
    done

    return 0
}

apply_permissions() {
    local dir

    for dir in "${SHARE_DIRS[@]}"; do
        info "opening up $dir"
        setfacl -R -m u::rwX,g::rX,o::--- "$dir"

        dim "setting default ACLs on every directory below, this can take a while"
        find "$dir" -type d -exec setfacl -d -m u::rwx,g::rx,o::--- {} +
    done

    # Secrets stay private, whatever happened above.
    local private=()
    for dir in "$HOME/.ssh" "$HOME/.gnupg"; do
        if [[ -e "$dir" ]]; then
            private+=("$dir")
        fi
    done

    if [[ ${#private[@]} -gt 0 ]]; then
        info "locking down ${private[*]}"
        setfacl -b -k "${private[@]}"
        chmod -R go= "${private[@]}"
    fi
}

setup_permissions() {
    have setfacl || die "setfacl not found, cannot manage ACLs"
    have getfacl || die "getfacl not found, cannot inspect ACLs"

    collect_share_dirs

    if permissions_already_shared; then
        ok "permissions already open for the group, left untouched"
        return 0
    fi

    apply_permissions
    ok "permissions changed, ${SHARE_DIRS[*]} are now group readable"
}

# ==============================================================================
#  Main
# ==============================================================================

main() {
    printf '\n%scluster_setup%s\n\n' "$C_BOLD" "$C_RESET"

    info "checking which cluster this is"
    detect_cluster
    ok "running on $CLUSTER"
    load_cluster_profile

    info "checking file permissions"
    setup_permissions

    printf '\n'
}

main "$@"
