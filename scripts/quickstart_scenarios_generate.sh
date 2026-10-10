#!/usr/bin/env bash
# Print the commands to start using fiveages-sim/scenarios_generate.
# Does not install packages or call an API.

cat <<'EOF'
# FiveAges scenarios_generate quick start
# Full notes: docs/QUICKSTART_scenarios_generate.md
# 中文: docs/QUICKSTART_scenarios_generate.zh-CN.md

git clone git@github.com:fiveages-sim/scenarios_generate.git
cd scenarios_generate
conda create -n scenarios python=3.10 -y
conda activate scenarios
pip install -r requirements.txt

# No API key: click start, goal, and pedestrians on the map.
# MWHLEPQKTIFZIAABAAAAAAA8_usd == Arena world grscenes_30
python scripts/manual_scenario_editor.py --scene MWHLEPQKTIFZIAABAAAAAAA8_usd

# Install YAML into Arena_W2 (from socialgen_w2):
#   ARENA_SRC=~/FiveAges-VLN/Arena_W2 \
#     ./scripts/install_scenario.sh path/to/generated_scenario.yaml

# Then launch (see docs/LAUNCH_W2.md):
#   cd ~/FiveAges-VLN/arena_ws && source ./arena
#   ros2 launch arena_bringup arena.launch.py \
#     world:=grscenes_30 robot:=FiveAges_W2 scenario:=scenario_001 save_data:=false
EOF
