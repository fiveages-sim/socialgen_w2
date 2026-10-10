# 快速开始：fiveages-sim/scenarios_generate

Fork：https://github.com/fiveages-sim/scenarios_generate

这个仓库只写场景 YAML。它不启动 Isaac，也不训练 InternNav。有了 YAML 之后，按 [LAUNCH_W2.zh-CN.md](LAUNCH_W2.zh-CN.md) 继续。

English: [QUICKSTART_scenarios_generate.md](QUICKSTART_scenarios_generate.md).

## 1. 环境

```bash
git clone git@github.com:fiveages-sim/scenarios_generate.git
cd scenarios_generate
conda create -n scenarios python=3.10 -y
conda activate scenarios
pip install -r requirements.txt
```

如果本机已经有 `~/SocialNav/scenarios_generate`，可以直接用。FiveAges 的文档和推送走 `fiveages-sim` 远程，不要推到 Social-Nav。

## 2. 不用 API key 编写场景

`MWHLEPQKTIFZIAABAAAAAAA8_usd` 就是 Arena 世界 `grscenes_30`。

```bash
conda activate scenarios
cd ~/SocialNav/scenarios_generate   # 或你自己的克隆
python scripts/manual_scenario_editor.py --scene MWHLEPQKTIFZIAABAAAAAAA8_usd
```

在地图上点出机器人起点、终点和行人，然后保存。输出：

```text
new_outputs/MWHLEPQKTIFZIAABAAAAAAA8_usd/scenario_001/
  generated_scenario.yaml
  llm_agents.json
  scenario_preview.png
```

预览里的线只是起点到终点。Arena 把机器人位姿当作起点，把最后一个路径点当作 Nav2 的目标。

## 3. 可选：Gemini

需要能访问 Google API（国内要用 TUN VPN），以及环境变量里的 key。不要把 key 提交进 git。

```bash
export DMX_BASE_URL=https://generativelanguage.googleapis.com/v1beta
export DMX_API_KEY=你的key
cp configs/llm_config.example.yaml configs/llm_config.local.yaml
```

在 `configs/llm_config.local.yaml` 里设置 `type: gemini`，模型用文本模型，例如 `gemini-3-flash-preview`。`configs/*local*.yaml` 已被 gitignore。

```bash
python scripts/generate_scenario_variants.py \
  --scene MWHLEPQKTIFZIAABAAAAAAA8_usd \
  --num 1 \
  --max-attempts 1
```

## 4. 把 YAML 装进 Arena_W2

```bash
cd ~/FiveAges-VLN/socialgen_w2
ARENA_SRC=~/FiveAges-VLN/Arena_W2 \
  ./scripts/install_scenario.sh \
  ~/SocialNav/scenarios_generate/new_outputs/MWHLEPQKTIFZIAABAAAAAAA8_usd/scenario_001/generated_scenario.yaml
```

然后用 `world:=grscenes_30` 和 `scenario:=scenario_001` 启动。见 [LAUNCH_W2.zh-CN.md](LAUNCH_W2.zh-CN.md)。
