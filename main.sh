filename="/tmp/log/messages"
keyword="请告诉我|请问"
pattern="speech_recognizer\.asr=($keyword).*.final=true"
split="speech_recognizer\.asr=|, \.final=true"
stop_pattern="老娘不会|努力学习|回答不上|等我学习|还在学习|我不会|难住了|还要再学习|补补课|我去学习|还不会"
stop_pattern2="speech_synthesizer\.dialog_id="

env
echo "正在监控文件: $filename"
echo "正在监控关键词: $keyword; 正则: $pattern"

awk_script='
  $0 ~ pattern {
    print $0
    print "捕获到输入问题："$2
    active=$2
  }
  $0 ~ stop_pattern {
    print "捕获到返回标记："$0
    if(active != "") {
      system("./dispatcher.sh "active)
    }
    active = ""
  }
  $0 ~ stop_pattern2 {
    print "捕获到tts调用标记："$0
    active = ""
  }
'

tail -n0 -f "$filename" | awk -F "$split" -v stop_pattern2="$stop_pattern2" -v stop_pattern="$stop_pattern" -v pattern="$pattern" -v awk_script="$awk_script" "$awk_script"
