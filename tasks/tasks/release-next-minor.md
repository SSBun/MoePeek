# 发布并安装 MoePeek 下一个次版本

| Field | Value |
| --- | --- |
| Status | Completed (2026-11-24 11:40) |
| Kind | Task |

## Target
- [x] T1: 全部本地改动已提交并推送到远端
- [x] T2: 下一个次版本已在远端发布
- [x] T3: 本机 Mac 已安装并核实同一发布版本

## Plan

1. 更新版本元数据，构建并校验发布附件。
2. 提交全部本地改动，推送主分支，上传并发布经过校验的附件。
3. 独立下载发布附件校验，备份并更新本机应用，核实运行版本。

## Execution Log

### 001 — 确定发布版本与构建路径

用户确认发布目标。远端最近发布及本机安装版本均为 v0.15.0，本地已有来自上游的 v0.21.0 标签。按确认的版本发布 MoePeek v0.22.0（build 6）。远端 Prod 环境和仓库未列出签名 secrets，沿用上次发布的本机开发签名构建路径，使用 GitHub Release 上传成品。已更新版本元数据和更新日志，Release 构建进行中。

### 002 — 发布并安装

Release 构建通过。发布提交 `91f9e41a71dfad7f87f64a6e99c5db736fdf379b` 推送到 `origin/main`，GitHub 的 `v0.22.0` 标签指向同一提交。正式 Release 的四个附件 SHA-256 与本地一致。完整远端下载在超时前只取得部分大文件，安装使用与 GitHub 摘要一致的本地 DMG。DMG 校验和应用深度签名通过，替换后核实 `/Applications/MoePeek.app` 为 0.22.0（6），进程已从安装路径启动。旧应用备份在 `~/Library/Application Support/MoePeek Backups/20261124-113900/MoePeek.app`。

## Task Summary

**发布版本**（[构建配置](../../Project.swift)、[更新日志](../../CHANGELOG.md)）将应用版本更新为 0.22.0（build 6），记录智能翻译候选复制行为及安装限制。

## Self Assessment

| 维度 | 等级 | 依据和证据 | 局限 |
| --- | --- | --- | --- |
| 简易性 | S | 沿用现有归档、DMG 和 GitHub Release 流程，无发布基础设施变更。 | 无实质缺口。 |
| 稳定性 | A | Release 归档、DMG、ZIP、深度签名、安装版本与启动均已核实。 | 未运行测试套件或完整界面验收，应用未经公证。 |
| 完整性 | A | 已提交、推送、发布并安装，远端标签及附件摘要已核对。 | 大附件的远端完整下载超时，安装包使用已核对远端摘要的本地副本。 |

## Result

- T1: 全部七个待提交文件纳入 91f9e41，已推送 origin/main。
- T2: GitHub 正式发布 v0.22.0，标签指向 91f9e41，四附件 SHA-256 与本地一致。
- T3: 从与 GitHub SHA-256 一致的 DMG 安装，深度签名通过，0.22.0 build 6 从 /Applications/MoePeek.app 启动。
- Review gate: Skipped — See Review Assessment for the recorded exemption
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R1
- State: Current
- Reason: 任务的改动为版本元数据及现有流程发布，无新增运行代码或基础设施。
- Snapshot: Git release 91f9e41a71dfad7f87f64a6e99c5db736fdf379b, DMG SHA256 828bca8369629193eb530a1e0881b0e364bf7b0fb1a9ac47cfd40c81a18f2e0c
- Evidence: 见执行日志 002、App 版本和 GitHub 附件摘要。
- Result clarity: 发布目标明确，版本和 build 可直接读取。
- Bounded impact: 手动安装发布，未更改业务代码或自动更新配置。
- Low risk: 旧应用已备份，官方安装包开发签名及未公证限制已披露。
- Sufficient verification: Release 归档、DMG 与 ZIP 完整性、深度签名、GitHub 标签及摘要和本机启动通过。
- Task fingerprint: bca55f9e7c3ef78a56ff99dd2d92c9d5ac4a8a3e61897129271b829f5655b613

## Verification

- Passed: 验证 91f9e41 与发布标签一致，安装包摘要与 GitHub 一致，应用已在本机以 0.22.0 build 6 启动。
