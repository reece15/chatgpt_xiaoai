

# 将以下命令加入开机启动脚本 /data/user.sh

sleep 3
export API="pandora进行聊天的接口"
export COOKIE_API="获取cookie的接口"
cd /data/chatgpt/ && ./main.sh >/tmp/log/gpt.log &
