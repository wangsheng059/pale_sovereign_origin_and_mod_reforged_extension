# 亡灵主宰起源与重铸扩展

[English](README.md)

当前源码快照：早期开发版本 V1.3.0（2026-11-26），亡灵主宰 1.7.12、背景专属特技 1.6.16。

这是一个围绕《战场兄弟》（Battle Brothers）亡灵主宰起源及 Reforged（重铸）扩展制作的模组合集。玩家扮演一位重建战团的死灵法师，招募常驻亡灵，体验分支成长、原创事件、技能、美术和战役机制。

## 玩法特色

- 在勇士与天灾两条路线中作出选择，各自拥有不同的亡灵成长方式和资源机制；常驻亡灵升阶为勇士路线专属。
- 征召并培养常驻亡灵，体验其专属特技、特质、身世和升阶分支。
- 探索原创事件、野心、美术、技能及战役机制，包括建立亡灵古堡。
- 使用整合包改进后的自动战斗，让队伍协同作战并运用亡灵主宰技能。

本仓库包含四个本地合集的源码与构建工具：

| 合集 | 内容 |
| --- | --- |
| `zz_local_integration.zip` | 亡灵主宰起源及跨模组联动 |
| `zz_local_rules.zip` | 本地玩法规则，包括背景专属特技 |
| `zz_local_campaign.zip` | 战役与内容模组，包括攻城内容 |
| `zz_local_interface.zip` | 界面与工具模组 |

本合集基于 GOG 版《战场兄弟》1.5.2.3、Reforged 0.9.3 和 Modern Hooks（现代钩子）0.7.0 开发；其他前置依赖见 [Readme.txt](Readme.txt)。现有的 `Readme.txt` 描述的是单独的预构建发行包，其安装说明和所含文件不代表本源码仓库的内容。

## 发行版本

单独的 V1.3.0 预构建发行包见 [Readme.txt](Readme.txt)，分为两种：有启动器版使用附带的启动器和 `zdata_cn.zip`；免启动器版使用定制汉化包，并运行游戏原生 Win32 客户端。本源码仓库不包含这些预构建安装包及其前置依赖。各版本的要求与安装步骤请查阅 `Readme.txt`。

## 源码目录

- `integration/`、`rules/`、`interface/`：维护中的模组模块与联动。
- `patches/`：构建时应用的补丁。
- `art/`：美术素材与参考资料。
- `manifest.json`：来源压缩包名称、校验值、文件冲突、模块与输出合集。
- `build.py`、`deploy.py`：构建和本地部署工具。

## 构建

需要 Python 3.11 或更高版本。构建还需要 `manifest.json` 中列出的原始来源 ZIP 压缩包，且 SHA-256（安全哈希算法）校验值须与清单一致。相对于本仓库的上一级目录，这些压缩包应位于：

```text
data_removed_mods/整合前_20261120/packages/
```

**这些来源压缩包和游戏前置依赖不包含在本仓库中。** 脚本要求仓库目录与 `data_removed_mods` 位于同一父目录下；仅克隆仓库无法完整重建合集。准备好所需输入后，执行：

```bash
python build.py audit --profile modular
python build.py build --profile modular
python build.py verify --profile modular
```

构建结果写入 `dist/modular/`。`deploy.py` 面向原本的本地游戏目录结构，会修改已安装的游戏文件；在其他环境使用前，请先检查脚本，并备份存档和已有模组。

## 许可证与第三方内容

版权持有人有权授权的原创内容采用 [MIT 许可证](LICENSE)。本合集还包含第三方模组及其修改内容，仍受各自作者的条款约束。详见 [THIRD_PARTY_NOTICES.txt](THIRD_PARTY_NOTICES.txt) 和 `manifest.json`；各第三方组件的再分发及重新授权许可尚未逐一核实。

《战场兄弟》和 Reforged 归各自权利人所有。本项目为非官方粉丝作品。
