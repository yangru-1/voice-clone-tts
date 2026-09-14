---
name: voice-clone-tts
description: 按参考音色和语速把文字转成语音（TTS）。当用户提供参考音频或视频（含人声），并要求把一段文字转换成音频、配音、朗读、语音合成，且音色/语速需与参考一致时使用。支持参考视频抽音轨、人声背景分离、片段裁剪、audio_to_audio_plus 生成、wav/mp3 交付。
---

# 参考音色文字转语音

## 总览

- 目标：用参考音频/视频中的人声音色与语速，朗读用户指定文字，交付 wav 或 mp3。
- 核心工具链：`audio_to_audio_plus`（生成）、`mediakit-cli`（抽音轨/人声分离/裁剪/转码）、`FileBatchUpload`（上传参考音频拿标准 URL）。
- 前提：先按 seed-audio 技能的 A2A 规范归一化参考指代（`@音频1`）；本文只描述工具链执行细节。

## 工作流

1. **准备参考音频**：得到 <120 秒、总量 <10MB 的纯净人声片段。
2. **上传参考**：下载片段到本地，用 `FileBatchUpload` 上传获取标准 URL。
3. **生成**：调用 `audio_to_audio_plus` 按参考音色语速朗读文字。
4. **交付**：下载生成音频为 .wav；用户要 mp3 时用 `transcode-audio` 转码后交付 .mp3。

## Step 1 准备参考音频

按输入类型选择路径（详细命令见 `references/mediakit.md`）：

| 输入 | 路径 |
| --- | --- |
| 视频文件/URL（含人声） | 抽音轨 `extract-audio` → 人声分离 `separate-voice` → 裁剪 `trim-audio` |
| 长音频（≥120 秒） | 人声分离 `separate-voice` → 裁剪 `trim-audio` |
| 短视频/短音频（<120 秒） | 可用原片段，或仅裁剪 |

- 先跑 `detect-voice-activity` 定位清晰人声段落，再选一段连续旁白（建议 30~90 秒）裁剪。
- 裁剪输出用 mp3 格式，控制文件体积。
- 全部 mediakit 命令为异步：提交后 `query-task --task-id <id> --poll-complete` 取终态。
- 可用 `scripts/prepare_reference.sh <输入路径或URL> <输出目录> [开始秒] [结束秒]` 一键完成 抽音轨→分离→裁剪→下载。

## Step 2 上传参考

- 把裁剪好的参考片段下载到本地（若脚本未下载）。
- 用 `FileBatchUpload` 上传，拿到 `aka.doubaocdn.com` 标准 URL。
- **不要**直接把 VOD 带 `auth_key` 的临时 URL 传给 `audio_to_audio_plus`——实测会失败。

## Step 3 生成

- 调用 `audio_to_audio_plus`：
  - `prompt`：按 A2A 规范，如 `使用 @音频1 的音色和语速朗读以下文字："<用户文字原文>"`；不改写、不增删用户文字。
  - `audio_reference_url_list`：只放 Step 2 上传得到的标准 URL。
  - 不传 `duration`，除非用户明确指定秒数。

## Step 4 交付

- 生成成功后下载音频到项目目录，保存为 `.wav`。
- 用户要 mp3：`mediakit-cli audio transcode-audio`（`--container-format MP3`，192kbps/44.1kHz 推荐）转码，再下载为 `.mp3`。
- 用 `present_files` 交付最终音频文件。

## 注意事项

- 参考音频任一超过 120 秒或总量超过 10MB，`audio_to_audio_plus` 会失败——先裁剪。
- 若生成失败且非时长/体积问题，重试一次；仍失败则检查参考 URL 是否为标准可访问 URL。
- 输出文件名以人可读的语义命名（如「主题-内容.mp3」），不放任务 ID。
