# W2 SocialGen pipeline

## 1. Author a scenario

Use [scenarios_generate](https://github.com/fiveages-sim/scenarios_generate). Output is `scenario.yaml` plus a preview PNG.

This repo already includes one example, generated for scene `MWHLEPQKTIFZIAABAAAAAAA8_usd`, which Arena calls **`grscenes_30`**:

```text
examples/grscenes_30/scenario_001/scenario.yaml
```

That file has 2 pedestrians and a robot start plus one goal. Arena uses the robot `pose` as the start and the **last** waypoint as the goal. Extra robot waypoints are ignored at runtime.

To make a better training episode, ask the generator for pedestrians that cross or meet the robot (head-on, crossing, overtaking). Routes that never meet the robot do not teach yielding.

## 2. Install the scenario into Arena_W2

```bash
export ARENA_SRC=/path/to/Arena_W2
./scripts/check_remotes.sh "$ARENA_SRC"
./scripts/install_scenario.sh grscenes_30 scenario_001
```

`install_scenario.sh` copies the YAML to:

```text
$ARENA_SRC/arena_simulation_setup/worlds/<world>/scenarios/<name>/scenario.yaml
```

It refuses to write if that checkout's `origin` contains `Social-Nav/`.

If `worlds/grscenes_30` does not exist, Arena_W2 does not yet have the SocialGen GRScenes worlds. Add those worlds on a FiveAges branch of Arena_W2. Do not commit that work to Social-Nav.

Rebuild or refresh the install space after adding a new scenario directory so the RViz scenario list sees it (`colcon build --symlink-install --packages-select arena_simulation_setup` when the package uses `data_files`).

## 3. Register W2

Copy `arena/FiveAges_W2/model_params.yaml` into:

```text
arena_robots/arena_robots/robots/FiveAges_W2/model_params.yaml
```

Before the first launch, replace the placeholders:

| Field | What to check |
| --- | --- |
| `usd_redirect` | Path Arena/Isaac can read. FaSim asset: `FiveAges_W2.usda` with `ROS=enable`. Arena also vendors `robot_usds/humanoid/FiveAges_W2`. |
| `robot_base_frame` | W2 art root is `base_link`. |
| lidar / depth `topic` | Must match the W2 ROS graph after the first Play (`ros2 topic list`). |
| `data_logger.camera_prim_suffix` | Draft from a W2 env layer: `Head_V1/head_link2/head_camera/head_camera`. Confirm on the spawned stage under `/World/Robots/...`. |
| footprint, `robot_radius`, `scale` | Measure from the USD. The numbers in the draft are starting points, not calibrated. |

GRScenes is mounted by `HOST_SCENES_DIR` in `~/FiveAges-VLN/arena_ws/.env`. Do not open `FiveAges_W2.usda` by hand in a separate Isaac and also spawn it from Arena.

Smoke from `~/FiveAges-VLN/arena_ws` (`source ./arena`, then inside the container):

```bash
ros2 launch arena_bringup arena.launch.py \
  sim:=isaac robot:=FiveAges_W2 world:=grscenes_30 \
  tm_robots:=scenario tm_obstacles:=scenario \
  save_data:=false
ros2 param set /task_generator_node task.scenario.file scenario_001
ros2 service call /task_generator_node/reset_task std_srvs/srv/Empty
```

In Isaac, press Play. Record only after both the robot and the pedestrians move: same launch with `save_data:=true`, then set `task.scenario.file` again. See [LAUNCH_W2.md](LAUNCH_W2.md).

## 4. Post-process

Arena's logger writes raw images and poses. Two scripts (in the Arena tree that has the SocialGen logger) turn that into LeRobot data:

```bash
python process_raw_to_dataset.py --data-path <traj_data_root>
python annotate_with_instructions.py --data-path <traj_data_root> --use-vlm
```

`process_raw_to_dataset.py` in the Social-Nav Arena is hardcoded for **Ai2_Bot2** (`CAMERA_HEIGHT_M ≈ 1.645`, pitch 30°, dataset key `132cm_30deg`). W2's head camera is a different height. Measure the prim, change `ROBOT_MODEL` and `CAMERA_*`, and use a new InternNav dataset name. Do not mix W2 episodes into an Ai2 `132cm_30deg` folder.

## 5. Fine-tune

Point [internnav_w2](https://github.com/fiveages-sim/internnav_w2) at the converted dataset (`traj_data/socialnav` or whatever key that repo registers). Stage 1 fine-tunes the vision-language planner. Stage 2 trains the short-horizon trajectory head. Keep `predict_step_num` the same across both stages.

[LightNav-0_W2](https://github.com/fiveages-sim/LightNav-0_W2) is a different stack. It does not consume these SocialGen episodes unless you add a converter.

## Safety

- `~/SocialNav/arena_ws` origin is `Social-Nav/Arena5.0`. Do not `git push` W2 work from that checkout.
- `~/SocialNav/InternNav` origin is `Social-Nav/InternNav`. Same rule.
- Push W2 collection docs only to `fiveages-sim/socialgen_w2`, and W2 Arena edits only to `fiveages-sim/Arena_W2`.
