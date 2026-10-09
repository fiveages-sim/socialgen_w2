# SocialGen for FiveAges W2

Scripts and docs for FiveAges-Sim members who want to **author social-navigation scenarios**, **run them in GRScenes with the W2 robot**, and **turn the recordings into InternNav fine-tuning data**.

This repository is not a fork of Arena or InternNav. It follows the same idea as [internnav_arx_lift2s](https://github.com/fiveages-sim/internnav_arx_lift2s): a small integration repo that points at the other pieces.

## What each repository does

| Repository | Role | Robot-specific? |
| --- | --- | --- |
| [scenarios_generate](https://github.com/fiveages-sim/scenarios_generate) | Draw waypoints and write `scenario.yaml` | No |
| [Arena_W2](https://github.com/fiveages-sim/Arena_W2) | Launch a GRScenes world, spawn a robot, run HuNav pedestrians and Nav2 | Yes, once W2 is registered |
| [robot_usds](https://github.com/fiveages-sim/robot_usds) | W2 USD (`humanoid/FiveAges_W2`) | Yes |
| [internnav_w2](https://github.com/fiveages-sim/internnav_w2) | InternNav inference and fine-tune entry for W2 | Yes |
| [LightNav-0_W2](https://github.com/fiveages-sim/LightNav-0_W2) | Separate W2 navigator | Not this data pipeline |

`scenario.yaml` only stores start poses, goals, and pedestrian waypoints in world metres. The same file can be used for any robot. Arena decides which USD is spawned (`robot:=FiveAges_W2`).

## What is already in this repo

| Path | Purpose |
| --- | --- |
| `examples/grscenes_30/scenario_001/scenario.yaml` | Example episode for Arena world `grscenes_30` (GRScenes id `MWHLEPQKTIFZIAABAAAAAAA8_usd`) |
| `arena/FiveAges_W2/model_params.yaml` | Draft Arena robot registration. Copy into an Arena checkout. Topics and camera height are not verified yet. |
| `scripts/install_scenario.sh` | Copy a scenario into an Arena world folder. Refuses a Social-Nav checkout. |
| `scripts/check_remotes.sh` | Fail if a git checkout's `origin` is `Social-Nav`. |
| `docs/pipeline.md` | Collect → post-process → fine-tune |

## Pipeline

```text
scenarios_generate  →  scenario.yaml
        │
        ▼
Arena_W2  robot:=FiveAges_W2  world:=grscenes_N  save_data:=true
        │   Nav2 drives (expert). HuNav moves pedestrians. Logger writes RGB-D.
        ▼
process_raw_to_dataset.py  +  annotate_with_instructions.py
        │
        ▼
internnav_w2 fine-tune
```

Nav2 is the teacher. InternNav learns from the recorded images and the path Nav2 actually drove. The straight line in a scenario preview is only start→goal. It is not the driven path.

## Important gap

[Arena_W2](https://github.com/fiveages-sim/Arena_W2) is still an unmodified fork of [voshch/Arena](https://github.com/voshch/Arena). The GRScenes worlds, HuNav launch, and SocialGen logger used in practice live on the Social-Nav Arena branch `feature/social_yielding` (`Social-Nav/Arena5.0`).

Do **not** push FiveAges or W2 commits to `Social-Nav/Arena5.0`, `Social-Nav/InternNav`, or `Social-Nav/hunav_sim`.

Before the first W2 collection run, Arena_W2 still needs:

1. GRScenes worlds (`world:=grscenes_N`) and their USD mounts.
2. `arena/FiveAges_W2/model_params.yaml` copied into `arena_robots/arena_robots/robots/FiveAges_W2/`.
3. A confirmed head-camera prim and ROS topic names (lidar / depth / `cmd_vel`).
4. Camera height and pitch in the post-process script. Do not reuse the Ai2_Bot2 setting `132cm_30deg` for W2.

## Quick start (after Arena_W2 can launch GRScenes)

```bash
# 1. Author or reuse a scenario (robot-agnostic)
git clone git@github.com:fiveages-sim/scenarios_generate.git
# see that repo's README. Example already in this repo:
#   examples/grscenes_30/scenario_001/scenario.yaml

# 2. Install it into YOUR FiveAges Arena checkout (not ~/SocialNav/arena_ws)
export ARENA_SRC=~/FiveAges-VLN/Arena_W2
./scripts/check_remotes.sh "$ARENA_SRC"
./scripts/install_scenario.sh grscenes_30 scenario_001

# 3. Register W2 (once)
mkdir -p "$ARENA_SRC/arena_robots/arena_robots/robots/FiveAges_W2"
cp arena/FiveAges_W2/model_params.yaml \
  "$ARENA_SRC/arena_robots/arena_robots/robots/FiveAges_W2/model_params.yaml"
# Then fix usd_redirect, lidar topics, and camera prim. See docs/pipeline.md.

# 4. Smoke, then record
# arena launch sim:=isaac robot:=FiveAges_W2 world:=grscenes_30 \
#   tm_robots:=scenario tm_obstacles:=scenario \
#   scenario:=scenario_001 save_data:=false
# Isaac Play → RViz Reset Task. When the robot AND pedestrians move, relaunch with save_data:=true.
```

Details: [docs/pipeline.md](docs/pipeline.md).
