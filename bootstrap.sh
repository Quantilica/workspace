#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

ORG="Quantilica"
BASE="https://github.com/$ORG"

WORKSPACE_PACKAGES=(
    quantilica-core
    quantilica-io
    quantilica-cli
    quantilica-catalog
    quantilica-cloud
    sidra-fetcher
    sidra-sql
    comex-fetcher
    datasus-fetcher
    inmet-fetcher
    pdet-fetcher
    rtn-fetcher
    tesouro-direto-fetcher
    bcb-sgs-fetcher
    bcb-sgs-sql
    sidra-pipelines
    bcb-sgs-pipelines
)

OTHER_REPOS=(
    ".github:.github"
    "docs:docs"
    "quantilica.github.io:quantilica.github.io"
)

clone_or_pull() {
    local repo="$1" dir="$2"
    if [ -d "$dir/.git" ]; then
        echo "↻  $dir — pulling..."
        git -C "$dir" pull --ff-only
    else
        echo "↓  $repo — cloning..."
        git clone "$BASE/$repo.git" "$dir"
    fi
}

echo "=== Workspace packages ==="
for repo in "${WORKSPACE_PACKAGES[@]}"; do
    clone_or_pull "$repo" "$repo"
done

echo ""
echo "=== Other repos ==="
for entry in "${OTHER_REPOS[@]}"; do
    IFS=: read -r repo dir <<< "$entry"
    clone_or_pull "$repo" "$dir"
done

echo ""
echo "=== Syncing uv workspace ==="
uv sync --all-packages

echo ""
echo "✓  Workspace ready."
