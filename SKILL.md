---
name: voice-clone-tts
description: 按参考音色和语速把文字转成语音（TTS），内置并保留参考人声音色与语速。当用户提供参考音频或视频（含人声），或要求使用内置默认音色，把一段文字转换成音频、配音、朗读、语音合成时使用。支持参考视频抽音轨、人声背景分离、片段裁剪、audio_to_audio_plus 生成、wav/mp3 交付。
---

# 参考音色文字转语音

## 总览

- 目标：用参考音频/视频中的人声音色与语速，朗读用户指定文字，交付 wav 或 mp3。
- **音色与语速的保留**：参考音频本身即音色与语速的载体。`audio_to_audio_plus` 会按参考音频的发音人音色和说话节奏朗读目标文字；prompt 中必须声明「音色和语速与 @音频1 一致」，生成结果即保留参考的音色与语速。
- 核心工具链：`audio_to_audio_plus`（生成）、`mediakit-cli`（抽音轨/人声分离/裁剪/转码）、`FileBatchUpload`（上传参考音频拿标准 URL）。
- 前提：先按 seed-audio 技能的 A2A 规范归一化参考指代（`@音频1`）；本文只描述工具链执行细节。

## 内置音色资产（默认音色）

- 默认参考音色已存放在 `assets/company-intro-voice.mp3`（公司介绍视频旁白音色，80 秒纯净人声，含其音色与语速）。
- **用户没有提供新的参考音频/视频时**：直接用该资产作参考，无需重新上传素材。
- 使用方式：`FileBatchUpload` 上传 `assets/company-intro-voice.mp3` 拿到标准 URL，作为 `audio_reference_url_list`。
- 备用参考 URL（已验证可用）：`https://aka.doubaocdn.com/s/N8nZlmZVTq`。仅当本地资产文件缺失或上传失败时使用；若该 URL 失效，重新 `FileBatchUpload` 资产文件即可。
- 新增音色：把新的 <120s、<10MB 的纯净人声片段放入 `assets/`（如 `assets/my-voice.mp3`），并在下文 Step 2 中改用它；或按 Step 1 从用户新给的视频/音频现场准备。

## 安装与自检（从 GitHub 克隆/下载后）

1. 必须保留完整目录结构，缺 `assets/` 或 `assets/company-intro-voice.mp3` 会导致无法使用默认音色。
2. 使用前先检查资产是否存在：
   ```bash
   ls -la assets/company-intro-voice.mp3
   ```
   若缺失，从 GitHub 仓库重新拉取该文件，或直接改用「备用参考 URL」。
3. 校验文件正常（1.28MB 左右、可播放 mp3）；空文件或损坏文件会导致生成失败或音色异常。

## 工作流

1. **确定参考音频**：用户给了新参考 → 按 Step 1 准备；没给 → 直接用内置 `assets/company-intro-voice.mp3`。
2. **上传参考**：用 `FileBatchUpload` 上传参考片段，获取标准 URL。
3. **生成**：调用 `audio_to_audio_plus`，prompt 声明按参考音色和语速朗读。
4. **交付**：下载生成音频为 .wav；用户要 mp3 时用 `transcode-audio` 转码后交付 .mp3。

## Step 1 准备参考音频（用户提供新参考时）

按输入类型选择路径（详细命令见 `references/mediakit.md`）：

| 输入 | 路径 |
| --- | --- |
| 视频文件/URL（含人声） | 抽音轨 `extract-audio` → 人声分离 `separate-voice` → 裁剪 `trim-audio` |
| 长音频（≥120 秒） | 人声分离 `separate-voice` → 裁剪 `trim-audio` |
| 短视频/短音频（<120 秒） | 可用原片段，或仅裁剪 |

- 先跑 `detect-voice-activity` 定位清晰人声段落，再选一段连续旁白（建议 30~90 秒）裁剪。
- 裁剪输出用 mp3 格式，控制文件体积（保证 <120 秒、<10MB）。
- 全部 mediakit 命令为异步：提交后 `query-task --task-id <id> --poll-complete` 取终态。
- 可用 `scripts/prepare_reference.sh <输入路径或URL> <输出目录> [开始秒] [结束秒]` 一键完成 抽音轨→分离→裁剪→下载。
- 新音色若需长期复用，把产物复制到 `assets/` 并改名，供后续直接使用。

## Step 2 上传参考

- 无新参考：上传内置 `assets/company-intro-voice.mp3`；有新参考：上传 Step 1 产物。
- 用 `FileBatchUpload` 上传，拿到 `aka.doubaocdn.com` 标准 URL。
- 上传失败时：改用「内置音色资产」中的备用参考 URL；仍失败则检查本地资产文件是否完整。
- **不要**直接把 VOD 带 `auth_key` 的临时 URL 传给 `audio_to_audio_plus`——实测会失败。

## Step 3 生成

- 调用 `audio_to_audio_plus`：
  - `prompt`：按 A2A 规范，模板为 `使用 @音频1 的音色和语速朗读以下文字："<用户文字原文>"`；**必须包含「音色和语速」字样**，确保保留参考的发音人音色与说话节奏；不改写、不增删用户文字。
  - `audio_reference_url_list`：只放 Step 2 得到的标准 URL（内置资产或新参考）。
  - 不传 `duration`，除非用户明确指定秒数。
- 生成后抽查验证：试听确认输出音色、语速与参考一致；若不像或异常，先核对参考 URL 是否为该音色文件、prompt 是否含「音色和语速」，再重试。

## Step 4 交付

- 生成成功后下载音频到项目目录，保存为 `.wav`。
- 用户要 mp3：`mediakit-cli audio transcode-audio`（`--container-format MP3`，192kbps/44.1kHz 推荐）转码，再下载为 `.mp3`。
- 用 `present_files` 交付最终音频文件。

## 注意事项

- 参考音频任一超过 120 秒或总量超过 10MB，`audio_to_audio_plus` 会失败——先裁剪。
- 若生成失败且非时长/体积问题，重试一次；仍失败则检查参考 URL 是否为标准可访问 URL。
- 输出文件名以人可读的语义命名（如「主题-内容.mp3」），不放任务 ID。

