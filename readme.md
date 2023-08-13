<h1 align="center">小爱接入ChatGPT</h1>

### 使用

- 前提1：小爱系统目录/data可写
- 前提2（用于自动获取token）：搭建[pandora-cloud-serverless](https://github.com/pengzhile/pandora-cloud-serverless)服务，并添加一个获取服务access_token的接口
- 将项目上传到小爱的 /data/chatgpt目录内。执行`chmod +x /data/chatgpt/*`添加执行权限
- 配置环境变量: 执行`export API="XXX"`添加openapi聊天接口; export COOKIE_API="XXX"添加cookie获取接口
- 测试: 执行./main.sh
- 开机自启: 将start.sh内内容添加到/data/user.sh，使开机自动启动

### 调试

- 调试gpt服务对接是否正常：执行`./gpt.sh test` 可以正常返回chatgpt回复数据
- 调试整个服务：唤醒小爱后，提问：请问xxx书讲的是什么？

### 服务调用流程

- main.sh 监控日志文件/tmp/log/messages是否变动--->满足条件后获取提问文本--->
- dispatcher.sh 调整小爱状态，取消当前播放内容--->播放等待chatgpt返回的提示信息--->
- gpt.sh 调用cloudflare代理的vercel服务pandora-cloud来获取access_token--->获取会话上下文--->调用chatgpt聊天接口，获取回复的信息--->
- dispatcher.sh 播放chatgpt回复的信息

### pandora-cloud修改

- 1.添加一个api。get调用时，后台直接使用用户名/密码调用fakeopen.com 来获取access_token，并设置到cookie
- 2.也可以不修改1，直接将access_token编辑到 `gpt.token`里即可（10天后需要重新操作）

### 功能列表

- [X]  以`请问/请告诉我`开头的问题，如果小爱没有回复正确结果，转到调用chatgpt
- [X]  无需OPENAPI KEY，直接调用部署于vercel的pandora-cloud服务(需要openapi账户登录)
- [X]  无需本地配置代理，vercel服务添加自定义域名，由cloudflare代理
- [X]  token缓存
- [X]  上下文保持
- [ ]  cookie时间处理
- [ ]  回答以流式处理

### 有用的信息

- [获取OPENAPI access_token](https://ai-20230626.fakeopen.com/auth1)
- [pandora-cloud-serverless](https://github.com/pengzhile/pandora-cloud-serverless)
- [旧版的拦截器(已失效)](https://github.com/FlashSoft/mico)
- [pandora-cloud-serverless 类似项目](https://github.com/ncs1024/pandora-chatgpt)
- [获取/data目录可写](http://javabin.cn/2021/xiaoai_fm.html)
