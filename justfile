set shell := ["bash", "-c"]

# List available recipes
default:
    @just --list

# Sync all workspace packages
sync:
    uv sync --all-packages

# Run tests for one package: just test sidra-fetcher
test pkg:
    uv run --package {{pkg}} pytest {{pkg}}/tests/ -v

# Lint the entire workspace
lint:
    uv run ruff check .

# Format the entire workspace
fmt:
    uv run ruff format .

# Check formatting without modifying files
fmt-check:
    uv run ruff format --check .

# Run lint + format check
check: lint fmt-check

# Pull all git repositories in the workspace (root and all sub-packages)
pull:
    find . -maxdepth 2 -name .git -exec sh -c 'echo "Pulling $(dirname "{}")..."; git -C "$(dirname "{}")" pull' \;





