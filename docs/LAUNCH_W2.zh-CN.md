# 启动 GRScenes、生成 FiveAges W2，并录制轨迹

工作区：`~/FiveAges-VLN/arena_ws`  
源码：`~/FiveAges-VLN/Arena_W2` 分支 `feature/w2-socialgen`  
场景：`arena_ws/.env` 里的 `HOST_SCENES_DIR`

English: [LAUNCH_W2.md](LAUNCH_W2.md).

## 开始之前

- 本机已有 Docker 镜像 `arena:dev`（之前为 Arena 编好的镜像可以直接用）。
- GRScenes-100 在磁盘上，并且 `arena_ws/.env` 的 `HOST_SCENES_DIR` 指向它。
- 工作区里的 `src/Arena` 指向 `Arena_W2`。
- 当前分支是 `feature/w2-socialgen`。
- 不要在这次启动的同时，再用 Isaac 单独打开 W2 的 USDA。

## 第 1 步 — 进入容器

```bash
cd ~/FiveAges-VLN/arena_ws
source ./arena
```

必须用 `source`。它把 `HOST_ARENA_WS_DIR` 设成这个工作区，并启动 compose 项目 `arena-arena_ws`。

## 第 2 步 — 在容器里编译一次

```bash
cd /opt/arena_ws
colcon build --symlink-install --packages-up-to arena_bringup arena_simulation_setup arena_robots hunav_sim
source install/setup.bash
```

`robot:=FiveAges_W2` 会去找 `install/arena_robots/share/arena_robots/robots/FiveAges_W2/model_params.yaml`。没有这个文件，这个机器人名字就没有注册。注册表在 `arena_robots`（FiveAges 包 `fa-arena-robots` / `fiveages-sim/robots`）。Arena_W2 的启动默认值已经是 `FiveAges_W2`。

## 第 3 步 — 试启动（不录数据）

```bash
ros2 launch arena_bringup arena.launch.py \
  sim:=isaac \
  robot:=FiveAges_W2 \
  world:=grscenes_30 \
  tm_robots:=scenario \
  tm_obstacles:=scenario \
  save_data:=false
```

- 必须写 `sim:=isaac`。启动默认的仿真器是 `dummy`。
- `world:=grscenes_30` 加载场景 `MWHLEPQKTIFZIAABAAAAAAA8_usd`。
- `tm_robots:=scenario` 和 `tm_obstacles:=scenario` 才会读 `scenario.yaml`。机器人位姿是起点，最后一个路径点是终点。
- 这个世界里已经有名为 `default` 的场景目录，第一次加载的是 `default`，不是 `scenario_001`。先指到 SocialGen 的文件再重置：

```bash
source /opt/arena_ws/install/setup.bash
ros2 param set /task_generator_node task.scenario.file scenario_001
ros2 service call /task_generator_node/reset_task std_srvs/srv/Empty
```

- 在 Isaac 里按 Play。

检查：

1. 场景里是 W2，不是别的机器人。
2. 行人在动。
3. 机器人朝目标走，并绕开行人（Nav2）。
4. 在容器里再开一个 shell：

```bash
source /opt/arena_ws/install/setup.bash
ros2 topic list | rg -i 'scan|lidar|camera|people'
```

如果激光话题不是 `${namespace}/scan`，写进 `model_params.yaml`。同时确认相机 prim。

录数据之前先停掉这次启动。`save_data:=false` 不会产生训练数据。

## 第 4 步 — 录制轨迹

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

栈起来之后，选中 SocialGen 场景并重置：

```bash
ros2 param set /task_generator_node task.scenario.file scenario_001
ros2 service call /task_generator_node/reset_task std_srvs/srv/Empty
```

按 Play。等这一局结束（机器人到达终点；导航失败时记录器会丢掉这一次）。

不想重启 Isaac、又要录多个场景时，保持这次 `save_data:=true` 的启动，在容器里另一个 shell 运行：

```bash
python3 /opt/arena_ws/src/Arena/scripts/batch_collect_scenarios.py \
  --robot FiveAges_W2 \
  --scenarios scenario_001
```

原始 episode 写在工作区里、Arena 源码的旁边：

```text
~/FiveAges-VLN/arena_ws/src/social_gen/traj_data/grscenes/grscenes_30/
```

容器里的路径是 `/opt/arena_ws/src/social_gen/traj_data/grscenes/grscenes_30/`。

## 第 5 步 — 把录像做成 W2 数据集

对原始 episode 运行 Arena 的 `process_raw_to_dataset.py`，再运行 `annotate_with_instructions.py`。

第一次转换之前，先改 `arena_isaac/arena_isaac/arena_isaac/data_logging/postprocess/process_raw_to_dataset.py`：把 `ROBOT_MODEL` 设成 `"FiveAges_W2"`，并用 W2 头部相机替换 `CAMERA_FORWARD_M`、`CAMERA_HEIGHT_M`、`CAMERA_PITCH_DEG`。文件里现在的大约前向 0.35 m、高度 1.645 m、俯仰 30° 属于另一台机器人，由这些数推出来的数据集目录名不能复用。在 Isaac 里量 prim `Head_V1/head_link2/head_camera/head_camera`，然后：

```bash
cd /opt/arena_ws
python3 -m arena_isaac.data_logging.postprocess.process_raw_to_dataset \
  --data-path src/social_gen/traj_data/grscenes/grscenes_30 \
  --keep-src
```

`--keep-src` 会留下原始 npy，直到你检查过一条 episode。确认没问题再去掉它。

指令标注需要 VLM 的 key，单独跑：

```bash
python3 -m arena_isaac.data_logging.postprocess.annotate_with_instructions \
  --data-path src/social_gen/traj_data/grscenes/grscenes_30 \
  --use-vlm
```

然后用 `internnav_w2` 里的 W2 训练脚本，在这个数据集上微调。

## 其他世界

本分支上 `world:=grscenes_1` 到 `world:=grscenes_30` 都是 GRScenes 世界。在 `scenarios_generate` 里按该场景的 USD 名字编写场景，用 `scripts/install_scenario.sh` 装进去，启动时传入对应的 `world:=`，并把 `task.scenario.file` 设成场景目录名。
