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
  world:=grscenes_30 \
  robot:=FiveAges_W2 \
  scenario:=scenario_001 \
  save_data:=false
```

- `world:=grscenes_30` 加载场景 `MWHLEPQKTIFZIAABAAAAAAA8_usd`。
- `scenario:=scenario_001` 加载已经装好的 YAML。机器人位姿是起点，最后一个路径点是终点。
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
  world:=grscenes_30 \
  robot:=FiveAges_W2 \
  scenario:=scenario_001 \
  save_data:=true
```

按 Play。等这一局结束（机器人到达终点，或场景超时）。想要更大的数据集，就用 `scenarios_generate` 再写更多场景，重复录制。

原始日志写在这个工作区里 Arena 的录制目录（本分支的 `record_data_dir` / `save_data` 输出）。把这些文件留在 FiveAges 工作区。

## 第 5 步 — 把录像做成 W2 数据集

对原始 episode 运行 Arena 的 `process_raw_to_dataset.py`，再运行 `annotate_with_instructions.py`。

运行前把相机常数改成 W2 头部相机。脚本里自带的大约 1.645 m、30°，以及数据集名 `socialnav_132cm_30_30`，属于另一台机器人。请换一个新名字，例如 `socialnav_w2_head`，并在 `internnav_w2` 里使用这个名字。

然后用 `internnav_w2` 里的 W2 训练脚本，在这个数据集上微调。

## 其他世界

本分支上 `world:=grscenes_1` 到 `world:=grscenes_30` 都是 GRScenes 世界。在 `scenarios_generate` 里按该场景的 USD 名字编写场景，用 `scripts/install_scenario.sh` 装进去，启动时传入对应的 `world:=` 和 `scenario:=`。
