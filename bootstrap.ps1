$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$org = "Quantilica"
$base = "https://github.com/$org"

$workspacePackages = @(
    "quantilica-core"
    "quantilica-analytics"
    "quantilica-cli"
    "quantilica-catalog"
    "sidra-fetcher"
    "sidra-sql"
    "comex-fetcher"
    "datasus-fetcher"
    "inmet-fetcher"
    "pdet-fetcher"
    "rtn-fetcher"
    "tesouro-direto-fetcher"
    "bcb-sgs-fetcher"
    "bcb-sgs-sql"
    "sidra-pipelines"
    "bcb-sgs-pipelines"
)

$otherRepos = @(
    @{ repo = ".github";              dir = ".github"              }
    @{ repo = "docs";                 dir = "docs"                 }
    @{ repo = "quantilica.github.io"; dir = "quantilica.github.io" }
)

function Clone-OrPull($repo, $dir) {
    if (Test-Path "$dir/.git") {
        Write-Host "↻  $dir — pulling..."
        git -C $dir pull --ff-only
    } else {
        Write-Host "↓  $repo — cloning..."
        git clone "$base/$repo.git" $dir
    }
}

Write-Host "=== Workspace packages ==="
foreach ($repo in $workspacePackages) {
    Clone-OrPull $repo $repo
}

Write-Host "`n=== Other repos ==="
foreach ($entry in $otherRepos) {
    Clone-OrPull $entry.repo $entry.dir
}

Write-Host "`n=== Syncing uv workspace ==="
uv sync --all-packages

Write-Host "`n✓  Workspace ready."
