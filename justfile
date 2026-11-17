set shell := ["bash", "-euo", "pipefail", "-c"]

# Lists the available commands.
default:
    @just --list

# Prepares the existing backend and frontend dependency graphs on an execution host.
setup: setup-backend setup-frontend

# Recreates only the declared backend environment and installs its existing inputs.
[group('backend')]
[working-directory('backend')]
setup-backend:
    uv venv --clear .venv
    uv pip install --python .venv/bin/python -r requirements.txt -r ../tools/ci-requirements.txt

# Installs the exact existing frontend lock, including its build prerequisites.
[group('frontend')]
[working-directory('frontend')]
setup-frontend:
    npm ci

# Runs every local source check using prepared tools, without importing the application.
check: check-python check-docker check-workflows

# Preserves the existing backend Ruff check.
[group('checks')]
[working-directory('backend')]
check-python:
    ruff check .

# Preserves the warning-level gate on every Dockerfile outside node_modules.
[group('checks')]
check-docker:
    find . -name 'Dockerfile*' -not -path '*/node_modules/*' -print0 | xargs -0 --no-run-if-empty hadolint --failure-threshold warning

# Checks command formatting, workflow safety and the retained Git history.
[group('checks')]
check-workflows:
    just --fmt --check
    actionlint
    zizmor --offline --no-progress .github
    gitleaks git --no-banner --redact --log-opts=--all .

# Applies only authored source/command fixes.
fix:
    just --fmt
    ruff check --fix backend

# Runs the existing synthetic backend schema/router tests in the prepared environment.
[working-directory('backend')]
test:
    .venv/bin/python -m unittest discover -s tests -v

# Builds the existing TypeScript/Vite frontend artifact.
[working-directory('frontend')]
build:
    npm run build

# Runs the existing mandatory remote-rule security check without telemetry.
[group('security')]
scan:
    uvx semgrep@1.182.1 scan --error --metrics off --config p/ci

# Runs the complete source, backend, frontend and remote-rule verification.
verify: check test build scan
