# mediakit-cli 参考命令

所有命令为 Cloud 异步模式：提交后返回 `task_id`，再轮询终态：

```bash
mediakit-cli shared query-task --task-id <task_id> --poll-complete
```

## 1. 抽音轨（视频→音频）

```bash
mediakit-cli editing extract-audio \
  --video-url "<视频路径或URL>" \
  --format wav
```

终态字段：`result.audio_url`（或顶层 `audio_url`，带 auth_key 的临时链接，24h 有效）。

## 2. 人声分离

```bash
mediakit-cli audio separate-voice \
  --audio-url "<音频URL>" \
  --output-format wav
```

终态字段：`voice_audio_url`（人声）、`background_audio_url`（背景）。

## 3. 语音端点检测（找清晰人声段）

```bash
mediakit-cli audio detect-voice-activity --audio-url "<音频URL>"
```

终态字段：`voice_segments`（起止时间戳数组）、`segment_count`。

## 4. 裁剪参考片段（<120s，mp3 控制体积）

```bash
mediakit-cli editing trim-audio \
  --audio-url "<人声音频URL>" \
  --start-time <开始秒> \
  --end-time <结束秒> \
  --format mp3
```

## 5. 转码为 MP3（生成结果交付用）

```bash
mediakit-cli audio transcode-audio \
  --audio-url "<wav音频URL或本地路径>" \
  --container-format MP3 \
  --audio '{"bitrate_kbps":192,"bitrate_mode":"cbr","sample_rate":44100,"channels":2}'
```

## 要点

- 输入支持公网 URL、本地文件路径、vod://、tos:// 四种协议；本地路径由 Cloud 适配器自动上传。
- JSON 参数（如 `--audio`）在 bash 中用单引号整体包裹。
- 临时链接有效期 24 小时，及时下载。
