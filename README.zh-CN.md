# SocialGen：FiveAges W2

中文说明。English: [README.md](README.md).

组织成员用这套流程编写行人场景、录制专家轨迹，再为 **FiveAges W2** 微调 InternNav。录制时开车的是 Nav2。InternNav 从录像里学习，不会去画场景编辑器里的那条预览线。

## 每个仓库做什么

| 仓库 | 作用 |
| --- | --- |
| [fiveages-sim/scenarios_generate](https://github.com/fiveages-sim/scenarios_generate) | 编写 `scenario.yaml`（机器人起点、终点、行人）。与具体机器人型号无关。 |
| [fiveages-sim/socialgen_w2](https://github.com/fiveages-sim/socialgen_w2) | 本仓库：流程文档、示例 YAML、W2 的 `model_params` 草稿、安装脚本。 |
| [fiveages-sim/Arena_W2](https://github.com/fiveages-sim/Arena_W2) 分支 `feature/w2-socialgen` | 启动 GRScenes + W2 + HuNav + Nav2，并录数据。 |
| [fiveages-sim/fa-arena-robots](https://github.com/fiveages-sim/fa-arena-robots) | Arena 注册表（`model_params.yaml`）。目前是 `FiveAges_W2`。 |
| [fiveages-sim/robot_usds](https://github.com/fiveages-sim/robot_usds) 与 [fa-w2-usds](https://github.com/fiveages-sim/fa-w2-usds) | USD 资产。只有 USD 不能在 Arena 里生成机器人。 |
| `internnav_w2` | 用 W2 数据集微调 InternNav。 |

不要把 FiveAges 或 W2 的改动推到 Social-Nav 的远程仓库。`scripts/check_remotes.sh` 在 `origin` 含有 `Social-Nav/` 时会失败。

## 流程

```text
scenarios_generate
  → scenario.yaml
  → Arena_W2（GRScenes + FiveAges_W2 + HuNav + Nav2）
  → 录制的 episode
  → process_raw_to_dataset.py（用 W2 相机，新的数据集名字）
  → annotate_with_instructions.py
  → internnav_w2 微调
```

1. **编写场景。** 手动编辑器或 Gemini 写出起点、终点（机器人路径点的最后一个）和行人。预览图上的黑线只是起点到终点。真正的路径由 Nav2 在运行时规划。
2. **启动。** Arena 按 `world:=grscenes_N` 加载 GRScenes USD，按 `robot:=FiveAges_W2` 生成机器人，并加载 `scenario:=...`。YAML 里的机器人位姿是起点，最后一个路径点是终点。复杂度 1 表示地图和目标位姿对 Nav2 是已知的。
3. **行驶。** Nav2 是专家教师（全局规划加社交局部规划）。行人来自 HuNav 的 `/people`。
4. **录制。** `save_data:=true` 写出 episode。先亲眼看到机器人和行人在动，再打开录制。
5. **后处理。** 用 **W2 头部相机** 的高度和俯仰把原始日志转成 InternNav 数据集。不要使用已有的 `socialnav_132cm_30_30`。那个名字对应的是另一台机器人的相机。
6. **训练。** 在 `internnav_w2` 里用新的数据集名字微调。

## 本机目录

```text
~/FiveAges-VLN/socialgen_w2     本仓库
~/FiveAges-VLN/Arena_W2         Arena 源码，分支 feature/w2-socialgen
~/FiveAges-VLN/arena_ws         Docker 工作区（src/Arena → Arena_W2）
~/FiveAges-VLN/fa-arena-robots  fiveages-sim/fa-arena-robots 的本地克隆
~/SocialNav/scenarios_generate  场景编写目录（或 FiveAges fork 的克隆）
```

`arena_ws` 和 `~/SocialNav/arena_ws` 是两套工作区。Docker 只挂载你启动的那一个，所以只放在 Social-Nav 里的 YAML，这个工作区看不到。

GRScenes 由 `~/FiveAges-VLN/arena_ws/.env` 里的 `HOST_SCENES_DIR` 挂载（本机是 `/home/zy/Datasets/datasets/GRScenes-100`）。场景 `MWHLEPQKTIFZIAABAAAAAAA8_usd` 对应 Arena 世界 `grscenes_30`。

## 快速开始：编写场景

完整命令：[docs/QUICKSTART_scenarios_generate.zh-CN.md](docs/QUICKSTART_scenarios_generate.zh-CN.md)。

```bash
cd ~/SocialNav/scenarios_generate
conda create -n scenarios python=3.10 -y
conda activate scenarios
pip install -r requirements.txt
python scripts/manual_scenario_editor.py --scene MWHLEPQKTIFZIAABAAAAAAA8_usd
```

把生成的 YAML 装进 Arena：

```bash
cd ~/FiveAges-VLN/socialgen_w2
ARENA_SRC=~/FiveAges-VLN/Arena_W2 \
  ./scripts/install_scenario.sh \
  ~/SocialNav/scenarios_generate/new_outputs/MWHLEPQKTIFZIAABAAAAAAA8_usd/scenario_001/generated_scenario.yaml
```

`grscenes_30` 的 `scenario_001` 已经装在 `feature/w2-socialgen` 上。

## 启动 GRScenes、生成 W2 并录轨迹

逐步说明：[docs/LAUNCH_W2.zh-CN.md](docs/LAUNCH_W2.zh-CN.md)（[English](docs/LAUNCH_W2.md)）。

```bash
cd ~/FiveAges-VLN/arena_ws
source ./arena
```

容器里第一次编译：

```bash
cd /opt/arena_ws
colcon build --symlink-install --packages-up-to arena_bringup arena_simulation_setup arena_robots hunav_sim
source install/setup.bash
```

先不录文件。必须写 `sim:=isaac`（默认是 `dummy`）。`tm_robots` 和 `tm_obstacles` 都要是 `scenario`，才会用 YAML 里的起点和终点：

```bash
ros2 launch arena_bringup arena.launch.py \
  sim:=isaac \
  robot:=FiveAges_W2 \
  world:=grscenes_30 \
  tm_robots:=scenario \
  tm_obstacles:=scenario \
  save_data:=false
```

`grscenes_30` 里已经有一个叫 `default` 的场景，所以要改成 `scenario_001` 再重置：

```bash
ros2 param set /task_generator_node task.scenario.file scenario_001
ros2 service call /task_generator_node/reset_task std_srvs/srv/Empty
```

在 Isaac 里按 Play。确认 W2 和行人都在动，Nav2 会绕开行人。然后停掉，用同样的参数把 `save_data:=true` 再录一次。逐步说明见 [docs/LAUNCH_W2.zh-CN.md](docs/LAUNCH_W2.zh-CN.md)。

Play 之后、相信日志之前，先看传感器：

```bash
ros2 topic list | rg -i 'scan|lidar|camera|people'
```

把看到的 LaserScan 话题写进 `arena/FiveAges_W2/model_params.yaml` 的 lidar `topic`。头部相机 prim 目前是 `Head_V1/head_link2/head_camera/head_camera`。足迹和半径是 LinkHou 底盘的初始值；如果机器人蹭墙，再量一次。

## 录完之后

用 Arena 的数据脚本处理新 episode，填入 W2 相机常数，并使用一个**新的**数据集名字。然后做指令标注，在 `internnav_w2` 里训练。

不要把 W2 的 episode 混进用另一台机器人相机高度和俯仰录出来的数据集。

## 再加一台组织里的机器人

USD 列表：https://github.com/fiveages-sim/robot_usds

1. 增加 `arena_robots/robots/<名字>/model_params.yaml`（从 `FiveAges_W2` 复制）。
2. 把 `usd_redirect` 指到那台机器人的 USD。
3. 启动时写 `robot:=<名字>`。

没有这个文件，Arena 就不能生成该机器人。

## 注册表仓库

W2 注册表已经在 [fiveages-sim/fa-arena-robots](https://github.com/fiveages-sim/fa-arena-robots)。本机已经可以启动：`model_params.yaml` 在 `Arena_W2/arena_robots/.../robots/FiveAges_W2/`。等其他成员只需要克隆 FiveAges 注册表时，把 Arena_W2 的 `arena_robots` 子模块改成 `git@github.com:fiveages-sim/fa-arena-robots.git`。
