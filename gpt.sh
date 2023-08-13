# shellcheck disable=SC2155

text=$1
host="https://chat.openai.com/"
conversation_api="$API"
cookie_api="$COOKIE_API"

# token缓存，10天 FIXME 未校验cookie过期时间，目前以文件创建时间为开始时间
file_cache_token="gpt.token"
expires_days=$((10 * 24 * 60 * 60))

# 状态缓存，上下文会话保持时间(不限时)
file_cache_state='gpt.state'
expires_seconds=$((60 * 3))


create_not_existed_file() {
  [ -s "$1" ] || echo "" > "$1"
}

# 从token缓存获取token，如果过期就刷新缓存
get_or_refresh_token() {
  local file_time=$(ls -l --full-time "$file_cache_token" | awk '{print $6, $7}')
  local file_timestamp=$(date -d "$file_time" +%s)
  local current_timestamp=$(date +%s)
  local time_diff=$((current_timestamp - file_timestamp))

  local token=$(cat "$file_cache_token" | awk -F 'token:' '/token:/ {print $2}')

  # 检查时间差是否大于expires_days
  if [ -z "$token" ] || [ "$time_diff" -gt "$expires_days" ]; then
    echo "刷新token缓存..."
    token=$(curl -I -s -k "$cookie_api" | awk -F '; Expires=|access-token=' '/set-cookie/ { result=$2} END{print result}')
    echo "token:$token" > $file_cache_token
  fi

  cat $file_cache_token
}

# 获取会话上下文
get_prev_message() {
  local file_time=$(ls -l --full-time "$file_cache_state" | awk '{print $6, $7}')
  local file_timestamp=$(date -d "$file_time" +%s)
  local current_timestamp=$(date +%s)
  local time_diff=$((current_timestamp - file_timestamp))

  local content=$(cat "$file_cache_state"|grep "message_id:")
  # 时间差是否大于expires_seconds,生成新会话
  if [ -z "$content" ] || [ "$time_diff" -gt "$expires_seconds" ]; then
    echo "会话已过期，创建新会话..."
    local _parent_message_id=$(cat /proc/sys/kernel/random/uuid)
    content="parent_message_id:$_parent_message_id;conversation_id:"
    echo "$content" > $file_cache_state
  fi
  cat $file_cache_state
}

# 初始化文件
echo "初始化缓存文件..."
create_not_existed_file $file_cache_token
create_not_existed_file $file_cache_state

# 获取token
echo "开始获取token..."
access_token=$(get_or_refresh_token | awk -F 'token:' '/token:/ { result=$2} END {print result}')
echo "获取到token: $access_token"

# 获取会话上下文
echo "获取会话上下文..."
state=$(get_prev_message | awk -F 'parent_message_id:|;conversation_id:' '/message_id:/ { result=$2" "$3} END{print result}')
parent_message_id=$(echo "$state" | awk '{print $1}')
conversation_id=$(echo "$state" | awk '{print $2}')

# 生成调用参数
x_auth="X-Authorization:Bearer $access_token"
message_id=$(cat /proc/sys/kernel/random/uuid)

if [ -z "$conversation_id" ]; then
  conversation_part=""
else
  conversation_part="\"conversation_id\":\"$conversation_id\", "
fi
message_text="假设你是一个名为花花的智能音箱助手，在以后的回答中，请尽可能简短概括的回答问题，不要做多余的解释，我的第一个问题是：$text"
message="{\"action\":\"next\",\"messages\":[{\"id\":\"$message_id\",\"author\":{\"role\":\"user\"},\"content\":{\"content_type\":\"text\",\"parts\":[\"$message_text\"]}}], $conversation_part\"parent_message_id\":\"$parent_message_id\",\"model\":\"text-davinci-002-render-sha\",\"timezone_offset_min\":-480,\"history_and_training_disabled\":false}"

# 发起POST请求，并模拟浏览器行为
echo "开始请求chatgpt服务...conversation_id: $conversation_id"
curl -k -s -X POST -H "$x_auth" \
     -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/92.0.4515.131 Safari/537.36" \
     -H "Accept: text/event-stream" \
     -H "Referer: $host" \
     -H "Origin: $host" \
     -H "Cache-Control: no-cache" \
     -H "Content-Type: application/json" \
     -d "$message" \
      "$conversation_api" | while IFS= read -r line; do
        message_item=$(echo $line|grep "\"role\": \"assistant\"" | awk -F 'parts\": \\[\"|\"\\]}, \"status' '{print $2}')

        if [ -n "$(echo "$message_item"|tr -d '[ \t\n\r]')" ]; then
          # 解析事件数据
          echo "$message_item"
          conversation_id=$(echo $line|grep "message" | awk -F 'conversation_id\": \"' '{print $2}'|awk -F '"' '{print $1}'|tr -d '[ \t\n\r]')
          echo "parent_message_id:$message_id;conversation_id:$conversation_id" > "$file_cache_state"
          prev=$message_item
        fi

        if [ -n "$(echo $line | grep "[DONE]")" ]; then
          echo "results:${prev}"
        fi
      done
