#!/usr/bin/env bash
# Copy a scenario YAML into an Arena_W2 world folder.
# Refuses checkouts whose origin is Social-Nav.
#
# Usage:
#   export ARENA_SRC=~/FiveAges-VLN/Arena_W2
#   ./scripts/install_scenario.sh [world] [scenario_name] [yaml]
#
# Defaults:
#   world=grscenes_30
#   scenario_name=scenario_001
#   yaml=examples/grscenes_30/scenario_001/scenario.yaml
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
world="${1:-grscenes_30}"
name="${2:-scenario_001}"
yaml="${3:-${here}/examples/grscenes_30/scenario_001/scenario.yaml}"

if [[ -z "${ARENA_SRC:-}" ]]; then
  echo "Set ARENA_SRC to your fiveages-sim/Arena_W2 checkout." >&2
  exit 2
fi
if [[ ! -f "${yaml}" ]]; then
  echo "Scenario YAML not found: ${yaml}" >&2
  exit 2
fi

"${here}/scripts/check_remotes.sh" "${ARENA_SRC}"

world_dir="${ARENA_SRC}/arena_simulation_setup/worlds/${world}"
if [[ ! -d "${world_dir}" ]]; then
  echo "Arena world directory does not exist:" >&2
  echo "  ${world_dir}" >&2
  echo "Arena_W2 does not yet contain this GRScenes world." >&2
  echo "Add grscenes worlds on the FiveAges Arena branch before installing." >&2
  exit 1
fi

dest="${world_dir}/scenarios/${name}"
mkdir -p "${dest}"
cp "${yaml}" "${dest}/scenario.yaml"
echo "Installed ${dest}/scenario.yaml"
