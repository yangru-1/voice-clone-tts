#!/usr/bin/env bash
# 参考人声准备脚本：从视频/音频一键得到 <120s 的纯净人声参考片段（mp3）。
# 用法: prepare_reference.sh <输入路径或URL> <输出目录> [开始秒] [结束秒]
#   输入为视频 → 自动抽音轨 → 人声分离 → 裁剪
#   输入为音频 → 自动人声分离 → 裁剪
#   默认裁剪 0~80 秒，可传 开始秒 结束秒 覆盖
set -euo pipefail

INPUT="$1"
OUTDIR="$2"
START="${3:-0}"
END="${4:-80}"

mkdir -p "$OUTDIR"

get_task_id() {
  python3 -c 'import sys,json;print(json.load(sys.stdin)["task_id"])'
}

poll_result() {
  local tid="$1"
  mediakit-cli shared query-task --task-id "$tid" --poll-complete 2>/dev/null \
    | python3 -c 'import sys,json;d=json.load(sys.stdin);print(d.get("result",d).get("url",d.get("url",d.get("audio_url",d.get("voice_audio_url","")))))' 2>/dev/null \
    || mediakit-cli shared query-task --task-id "$tid" --poll-complete
}

echo "==> [1/4] 判断输入类型"
EXT="${INPUT##*.}"
EXT=$(echo "$EXT" | tr '[:upper:]' '[:lower:]')
case "$EXT" in
  mp4|mov|mkv|avi|flv|ts|wmv|m4v)
    echo "    视频输入，抽音轨..."
    RAW_JSON=$(mediakit-cli editing extract-audio --video-url "$INPUT" --format wav 2>/dev/null)
    TID=$(echo "$RAW_JSON" | get_task_id)
    AUDIO_URL=$(mediakit-cli shared query-task --task-id "$TID" --poll-complete 2>/dev/null \
      | python3 -c 'import sys,json;d=json.load(sys.stdin);print(d.get("result",{}).get("audio_url") or d.get("audio_url",""))')
    ;;
  *)
    echo "    音频输入，直接使用"
    AUDIO_URL="$INPUT"
    ;;
esac
[ -n "$AUDIO_URL" ] || { echo "错误: 未取得音轨 URL"; exit 1; }

echo "==> [2/4] 人声分离"
RAW_JSON=$(mediakit-cli audio separate-voice --audio-url "$AUDIO_URL" --output-format wav 2>/dev/null)
TID=$(echo "$RAW_JSON" | get_task_id)
VOICE_URL=$(mediakit-cli shared query-task --task-id "$TID" --poll-complete 2>/dev/null \
  | python3 -c 'import sys,json;d=json.load(sys.stdin);print(d.get("result",{}).get("voice_audio_url") or d.get("voice_audio_url",""))')
[ -n "$VOICE_URL" ] || { echo "错误: 未取得人声音轨 URL"; exit 1; }

echo "==> [3/4] 裁剪 ${START}~${END}s 为 mp3"
RAW_JSON=$(mediakit-cli editing trim-audio --audio-url "$VOICE_URL" --start-time "$START" --end-time "$END" --format mp3 2>/dev/null)
TID=$(echo "$RAW_JSON" | get_task_id)
TRIM_URL=$(mediakit-cli shared query-task --task-id "$TID" --poll-complete 2>/dev/null \
  | python3 -c 'import sys,json;d=json.load(sys.stdin);print(d.get("result",{}).get("audio_url") or d.get("audio_url",""))')
[ -n "$TRIM_URL" ] || { echo "错误: 未取得裁剪后 URL"; exit 1; }

echo "==> [4/4] 下载到本地"
OUTFILE="$OUTDIR/reference_voice_${START}-${END}s.mp3"
curl -sL -o "$OUTFILE" "$TRIM_URL"
[ -s "$OUTFILE" ] || { echo "错误: 下载失败"; exit 1; }

echo "完成: $OUTFILE"
echo "下一步: 用 FileBatchUpload 上传该文件获取标准 URL，再调用 audio_to_audio_plus（prompt 用 @音频1 引用）。"
