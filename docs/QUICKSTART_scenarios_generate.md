# Quick start: fiveages-sim/scenarios_generate

Fork: https://github.com/fiveages-sim/scenarios_generate

This repo only writes scenario YAML. It does not launch Isaac or train InternNav. After you have a YAML, continue with [LAUNCH_W2.md](LAUNCH_W2.md).

中文：[QUICKSTART_scenarios_generate.zh-CN.md](QUICKSTART_scenarios_generate.zh-CN.md).

## 1. Environment

```bash
git clone git@github.com:fiveages-sim/scenarios_generate.git
cd scenarios_generate
conda create -n scenarios python=3.10 -y
conda activate scenarios
pip install -r requirements.txt
```

If you already have `~/SocialNav/scenarios_generate`, you can use that checkout. Keep FiveAges docs and pushes on the `fiveages-sim` remote.

## 2. Author a scenario without an API key

`MWHLEPQKTIFZIAABAAAAAAA8_usd` is Arena world `grscenes_30`.

```bash
conda activate scenarios
cd ~/SocialNav/scenarios_generate   # or your clone
python scripts/manual_scenario_editor.py --scene MWHLEPQKTIFZIAABAAAAAAA8_usd
```

Click the map to place the robot start, the robot goal, and pedestrians. Save. Outputs:

```text
new_outputs/MWHLEPQKTIFZIAABAAAAAAA8_usd/scenario_001/
  generated_scenario.yaml
  llm_agents.json
  scenario_preview.png
```

The preview line is start → goal. Arena uses the robot pose as the start and the last waypoint as the Nav2 goal.

## 3. Optional: Gemini

Needs a reachable Google API (from China, a TUN VPN) and a key in the environment. Do not commit the key.

```bash
export DMX_BASE_URL=https://generativelanguage.googleapis.com/v1beta
export DMX_API_KEY=your_key
cp configs/llm_config.example.yaml configs/llm_config.local.yaml
```

In `configs/llm_config.local.yaml` set `type: gemini` and a text model such as `gemini-3-flash-preview`. `configs/*local*.yaml` is gitignored.

```bash
python scripts/generate_scenario_variants.py \
  --scene MWHLEPQKTIFZIAABAAAAAAA8_usd \
  --num 1 \
  --max-attempts 1
```

## 4. Install the YAML into Arena_W2

```bash
cd ~/FiveAges-VLN/socialgen_w2
ARENA_SRC=~/FiveAges-VLN/Arena_W2 \
  ./scripts/install_scenario.sh \
  ~/SocialNav/scenarios_generate/new_outputs/MWHLEPQKTIFZIAABAAAAAAA8_usd/scenario_001/generated_scenario.yaml
```

Then launch with `sim:=isaac`, `world:=grscenes_30`, `tm_robots:=scenario`, `tm_obstacles:=scenario`, and set `task.scenario.file` to `scenario_001`. See [LAUNCH_W2.md](LAUNCH_W2.md).
