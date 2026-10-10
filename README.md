# SocialGen for FiveAges W2

English guide for the FiveAges data pipeline. 中文见 [README.zh-CN.md](README.zh-CN.md).

Org members use this stack to author pedestrian scenarios and record expert trajectories, then fine-tune InternNav for the **FiveAges W2** robot. The robot that drives during recording is Nav2. InternNav learns from those recordings. It does not draw the preview line in the scenario editor.

## What each repo does

| Repo | Role |
| --- | --- |
| [fiveages-sim/scenarios_generate](https://github.com/fiveages-sim/scenarios_generate) | Author `scenario.yaml` (robot start, goal, pedestrians). Robot-agnostic. |
| [fiveages-sim/socialgen_w2](https://github.com/fiveages-sim/socialgen_w2) | This repo: pipeline docs, example YAML, W2 `model_params` draft, install helper. |
| [fiveages-sim/Arena_W2](https://github.com/fiveages-sim/Arena_W2) branch `feature/w2-socialgen` | Launches GRScenes + W2 + HuNav + Nav2 and records data. |
| `fiveages-sim/robots` (local: `~/FiveAges-VLN/fa-arena-robots`) | Arena registration (`model_params.yaml`) for FiveAges robots. Currently `FiveAges_W2`. |
| [fiveages-sim/robot_usds](https://github.com/fiveages-sim/robot_usds) and [fa-w2-usds](https://github.com/fiveages-sim/fa-w2-usds) | USD assets. A USD alone does not spawn in Arena. |
| `internnav_w2` | Fine-tune InternNav on the W2 dataset. |

Do not push FiveAges or W2 changes to Social-Nav remotes. `scripts/check_remotes.sh` exits if `origin` contains `Social-Nav/`.

## Pipeline

```text
scenarios_generate
  → scenario.yaml
  → Arena_W2 (GRScenes + FiveAges_W2 + HuNav + Nav2)
  → recorded episode
  → process_raw_to_dataset.py   (W2 camera, new dataset key)
  → annotate_with_instructions.py
  → internnav_w2 fine-tune
```

1. **Author.** The editor or Gemini writes a start pose, a goal (the last robot waypoint), and pedestrian agents. The black line in the preview is start → goal only. Nav2 plans the real path at runtime.
2. **Launch.** Arena loads the GRScenes USD for `world:=grscenes_N`, spawns `robot:=FiveAges_W2`, and loads `scenario:=...`. The robot pose in the YAML is the start. The last waypoint is the goal. Complexity 1 means the map and the goal pose are known to Nav2.
3. **Drive.** Nav2 is the expert teacher (global planner plus the social local planner). Pedestrians come from HuNav on `/people`.
4. **Record.** `save_data:=true` writes the episode. Do this only after you have seen the robot and the pedestrians move.
5. **Process.** Convert raw logs to the InternNav dataset format using the **W2 head camera** height and pitch. Do not reuse the existing `socialnav_132cm_30_30` key. That key is a different camera.
6. **Train.** Fine-tune on the new W2 dataset key in `internnav_w2`.

## Layout on this machine

```text
~/FiveAges-VLN/socialgen_w2     this repo
~/FiveAges-VLN/Arena_W2         Arena source, branch feature/w2-socialgen
~/FiveAges-VLN/arena_ws         Docker workspace (src/Arena → Arena_W2)
~/FiveAges-VLN/fa-arena-robots  local robots package (push to fiveages-sim/robots)
~/SocialNav/scenarios_generate  authoring checkout (or a clone of the FiveAges fork)
```

`arena_ws` is separate from `~/SocialNav/arena_ws`. Docker mounts the workspace you start, so a YAML that lives only under Social-Nav is invisible to this workspace.

GRScenes files are mounted from `HOST_SCENES_DIR` in `~/FiveAges-VLN/arena_ws/.env` (this machine: `/home/zy/Datasets/datasets/GRScenes-100`). Scene `MWHLEPQKTIFZIAABAAAAAAA8_usd` is Arena world `grscenes_30`.

## Quick start: author a scenario

Full command list: [docs/QUICKSTART_scenarios_generate.md](docs/QUICKSTART_scenarios_generate.md).

```bash
cd ~/SocialNav/scenarios_generate
conda create -n scenarios python=3.10 -y
conda activate scenarios
pip install -r requirements.txt
python scripts/manual_scenario_editor.py --scene MWHLEPQKTIFZIAABAAAAAAA8_usd
```

Copy the generated YAML into Arena:

```bash
cd ~/FiveAges-VLN/socialgen_w2
ARENA_SRC=~/FiveAges-VLN/Arena_W2 \
  ./scripts/install_scenario.sh \
  ~/SocialNav/scenarios_generate/new_outputs/MWHLEPQKTIFZIAABAAAAAAA8_usd/scenario_001/generated_scenario.yaml
```

`scenario_001` for `grscenes_30` is already installed on `feature/w2-socialgen`.

## Launch GRScenes with W2 and record

Details and the Chinese version: [docs/LAUNCH_W2.md](docs/LAUNCH_W2.md), [docs/LAUNCH_W2.zh-CN.md](docs/LAUNCH_W2.zh-CN.md).

```bash
cd ~/FiveAges-VLN/arena_ws
source ./arena
```

Inside the container, once:

```bash
cd /opt/arena_ws
colcon build --symlink-install --packages-up-to arena_bringup arena_simulation_setup arena_robots hunav_sim
source install/setup.bash
```

Smoke (no files written). `sim:=isaac` is required; the launch default is `dummy`. `tm_robots` and `tm_obstacles` must be `scenario` so the YAML start and goal are used:

```bash
ros2 launch arena_bringup arena.launch.py \
  sim:=isaac \
  robot:=FiveAges_W2 \
  world:=grscenes_30 \
  tm_robots:=scenario \
  tm_obstacles:=scenario \
  save_data:=false
```

`grscenes_30` already has a `default` scenario, so select `scenario_001` and reset:

```bash
ros2 param set /task_generator_node task.scenario.file scenario_001
ros2 service call /task_generator_node/reset_task std_srvs/srv/Empty
```

In Isaac, press Play. Confirm W2 and the pedestrians move, and that Nav2 is planning around people. Then stop and record with the same arguments and `save_data:=true`. Full steps: [docs/LAUNCH_W2.md](docs/LAUNCH_W2.md).

After Play, check the sensors before you trust the logs:

```bash
ros2 topic list | rg -i 'scan|lidar|camera|people'
```

Set the lidar `topic` in `arena/FiveAges_W2/model_params.yaml` to the LaserScan you see. Confirm the head camera prim `Head_V1/head_link2/head_camera/head_camera`. Footprint and radius are starting values from the LinkHou chassis; re-measure if the robot clips walls.

## After recording

Use the Arena data scripts on the new episode, with W2 camera constants, and write a **new** dataset name. Then run instruction annotation and train in `internnav_w2`.

Do not mix W2 episodes into a dataset recorded with another robot's camera height and pitch.

## Adding another org robot

USD list: https://github.com/fiveages-sim/robot_usds

1. Add `arena_robots/robots/<Name>/model_params.yaml` (copy `FiveAges_W2`).
2. Point `usd_redirect` at that USD.
3. Launch with `robot:=<Name>`.

Until that file exists, Arena cannot spawn the robot.

## One GitHub step still open

`~/FiveAges-VLN/fa-arena-robots` is committed locally (W2 registration plus the `fa-w2-usds` submodule). GitHub does not have `fiveages-sim/robots` yet, so the push was rejected. Create an empty repository `fiveages-sim/robots` (no README), then:

```bash
cd ~/FiveAges-VLN/fa-arena-robots
git push -u origin main
```

This machine can already launch: `model_params.yaml` is on disk under `Arena_W2/arena_robots/.../robots/FiveAges_W2/`. After the GitHub repo exists, point Arena_W2's `arena_robots` submodule at `git@github.com:fiveages-sim/robots.git` so other members clone only the FiveAges registration.
