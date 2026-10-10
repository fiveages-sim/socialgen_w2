# Launch GRScenes with FiveAges W2 and record trajectories

Workspace: `~/FiveAges-VLN/arena_ws`  
Source: `~/FiveAges-VLN/Arena_W2` branch `feature/w2-socialgen`  
Scenes: `HOST_SCENES_DIR` in `arena_ws/.env`

中文：[LAUNCH_W2.zh-CN.md](LAUNCH_W2.zh-CN.md).

## Before you start

- Docker image `arena:dev` exists (the image already built for Arena on this machine is fine).
- GRScenes-100 is on disk and `arena_ws/.env` points `HOST_SCENES_DIR` at it.
- `src/Arena` in the workspace points at `Arena_W2`.
- You are on branch `feature/w2-socialgen`.
- Do not open the W2 USDA in Isaac by hand at the same time as this launch.

## Step 1 — enter the container

```bash
cd ~/FiveAges-VLN/arena_ws
source ./arena
```

`source` is required. It sets `HOST_ARENA_WS_DIR` to this workspace and starts compose project `arena-arena_ws`.

## Step 2 — build once inside the container

```bash
cd /opt/arena_ws
colcon build --symlink-install --packages-up-to arena_bringup arena_simulation_setup arena_robots hunav_sim
source install/setup.bash
```

`robot:=FiveAges_W2` looks up `install/arena_robots/share/arena_robots/robots/FiveAges_W2/model_params.yaml`. If that file is missing, the robot name is not registered. The registration lives in `arena_robots` (FiveAges package `fa-arena-robots` / `fiveages-sim/robots`). The Arena_W2 launch default is already `FiveAges_W2`.

## Step 3 — smoke launch (no recording)

```bash
ros2 launch arena_bringup arena.launch.py \
  world:=grscenes_30 \
  robot:=FiveAges_W2 \
  scenario:=scenario_001 \
  save_data:=false
```

- `world:=grscenes_30` loads scene `MWHLEPQKTIFZIAABAAAAAAA8_usd`.
- `scenario:=scenario_001` loads the installed YAML. The robot pose is the start. The last waypoint is the goal.
- Press Play in Isaac.

Check:

1. The W2 robot is in the scene, not a different robot.
2. Pedestrians move.
3. The robot moves toward the goal and steers around people (Nav2).
4. In another shell inside the container:

```bash
source /opt/arena_ws/install/setup.bash
ros2 topic list | rg -i 'scan|lidar|camera|people'
```

Write the LaserScan topic into `model_params.yaml` if it is not `${namespace}/scan`. Confirm the camera prim.

Stop this launch before recording. A smoke run with `save_data:=false` does not produce training data.

## Step 4 — record trajectory data

```bash
source /opt/arena_ws/install/setup.bash
ros2 launch arena_bringup arena.launch.py \
  world:=grscenes_30 \
  robot:=FiveAges_W2 \
  scenario:=scenario_001 \
  save_data:=true
```

Press Play. Let the episode finish (robot reaches the goal, or the scenario timeout). Repeat with more scenarios from `scenarios_generate` for a larger set.

Raw logs are written under the Arena record directory inside the workspace (the `record_data_dir` / `save_data` output of this branch). Keep those files with the FiveAges workspace.

## Step 5 — turn recordings into a W2 dataset

On the raw episode, run Arena's `process_raw_to_dataset.py`, then `annotate_with_instructions.py`.

Change the camera constants to the W2 head camera before you run them. The script's built-in values (about 1.645 m and 30°) and the dataset name `socialnav_132cm_30_30` belong to a different robot. Pick a new key, for example `socialnav_w2_head`, and use that key in `internnav_w2`.

Then train with the W2 scripts in `internnav_w2` on that dataset key.

## Other worlds

`world:=grscenes_1` … `world:=grscenes_30` are the GRScenes worlds on this branch. Author the scenario in `scenarios_generate` against that scene's USD name, install it with `scripts/install_scenario.sh`, and pass the matching `world:=` and `scenario:=`.
