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
  sim:=isaac \
  robot:=FiveAges_W2 \
  world:=grscenes_30 \
  tm_robots:=scenario \
  tm_obstacles:=scenario \
  save_data:=false
```

- `sim:=isaac` is required. The launch default simulator is `dummy`.
- `world:=grscenes_30` loads scene `MWHLEPQKTIFZIAABAAAAAAA8_usd`.
- `tm_robots:=scenario` and `tm_obstacles:=scenario` read a `scenario.yaml`. The robot pose is the start. The last waypoint is the goal.
- That world already has a `default` scenario folder, so the first load is `default`, not `scenario_001`. Point the task generator at the SocialGen file, then reset:

```bash
source /opt/arena_ws/install/setup.bash
ros2 param set /task_generator_node task.scenario.file scenario_001
ros2 service call /task_generator_node/reset_task std_srvs/srv/Empty
```

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
  sim:=isaac \
  robot:=FiveAges_W2 \
  world:=grscenes_30 \
  tm_robots:=scenario \
  tm_obstacles:=scenario \
  save_data:=true
```

After the stack is up, select the SocialGen scenario and reset:

```bash
ros2 param set /task_generator_node task.scenario.file scenario_001
ros2 service call /task_generator_node/reset_task std_srvs/srv/Empty
```

Press Play. Let the episode finish (robot reaches the goal, or navigation fails and the logger discards that attempt).

To record several named scenarios without restarting Isaac, leave this launch running with `save_data:=true` and, in another container shell:

```bash
python3 /opt/arena_ws/src/Arena/scripts/batch_collect_scenarios.py \
  --robot FiveAges_W2 \
  --scenarios scenario_001
```

Raw episodes land in the workspace next to Arena:

```text
~/FiveAges-VLN/arena_ws/src/social_gen/traj_data/grscenes/grscenes_30/
```

Inside the container that path is `/opt/arena_ws/src/social_gen/traj_data/grscenes/grscenes_30/`.

## Step 5 — turn recordings into a W2 dataset

On the raw episode, run Arena's `process_raw_to_dataset.py`, then `annotate_with_instructions.py`.

Before the first conversion, edit `arena_isaac/arena_isaac/arena_isaac/data_logging/postprocess/process_raw_to_dataset.py`: set `ROBOT_MODEL = "FiveAges_W2"` and replace `CAMERA_FORWARD_M`, `CAMERA_HEIGHT_M`, and `CAMERA_PITCH_DEG` with the W2 head camera. The values in the file now (about 0.35 m forward, 1.645 m high, 30°) belong to a different robot, and the dataset folder names derived from them must not be reused. Measure the W2 prim `Head_V1/head_link2/head_camera/head_camera` in Isaac, then:

```bash
cd /opt/arena_ws
python3 -m arena_isaac.data_logging.postprocess.process_raw_to_dataset \
  --data-path src/social_gen/traj_data/grscenes/grscenes_30 \
  --keep-src
```

`--keep-src` leaves the raw npy in place until you have checked one episode. Drop it only after that check looks right.

Instruction annotation needs a VLM key and is a separate step:

```bash
python3 -m arena_isaac.data_logging.postprocess.annotate_with_instructions \
  --data-path src/social_gen/traj_data/grscenes/grscenes_30 \
  --use-vlm
```

Then train with the W2 scripts in `internnav_w2` on that dataset key.

## Other worlds

`world:=grscenes_1` … `world:=grscenes_30` are the GRScenes worlds on this branch. Author the scenario in `scenarios_generate` against that scene's USD name, install it with `scripts/install_scenario.sh`, pass the matching `world:=`, and set `task.scenario.file` to the scenario folder name.
