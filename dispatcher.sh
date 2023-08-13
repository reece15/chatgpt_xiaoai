text=$1
echo "== 分发器获取到句子：$1"

if [ -z "$(echo $text| tr -d '[ \t\n\r]')" ]; then
  echo "ERROR! 跳过空问题"
else
  seq 1 200 | while read line; do
    code=$(ubus call mediaplayer player_play_operation {\"action\":\"resume\"} | awk -F 'code":' '{print $2}')
    if [[ "$code" -eq "0" ]]; then
      echo "== 停止成功"
      break
    fi
    sleep 0.1
  done

  ubus call mediaplayer player_play_operation {\"action\":\"pause\"} >/dev/null 2>&1
  ubus call mibrain text_to_speech "{\"text\":\"以下答案来自gpt：\",\"save\":0}" >/dev/null 2>&1
  echo "请求gpt服务..."
  message=$(./gpt.sh $text | awk -F 'results:' '/results:/ { result = $2 } END { print result }')

  # 开始tts播放
  echo "== 播放TTS信息：$message"
  ubus call mibrain text_to_speech "{\"text\":\"$message\",\"save\":0}" >/dev/null 2>&1
fi