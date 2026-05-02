#!/bin/bash

# --- 样式定义 ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# --- 信号处理函数 ---
function ask_background {
    echo -e "\n${YELLOW}>>> 检测到中断。${NC}"
    # 强制从终端读取输入
    read -p "登录已完成？是否开启后台自动运行? (y/n): " confirm < /dev/tty
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        pkill -f tg.py 2>/dev/null
        nohup /root/Telegram-Name/venv/bin/python3 /root/Telegram-Name/tg.py > /root/Telegram-Name/tg.log 2>&1 &
        echo $! > /root/Telegram-Name/tg.pid
        echo -e "${GREEN}>>> 已转入后台运行！PID: $(cat /root/Telegram-Name/tg.pid)${NC}"
    else
        echo -e "${RED}>>> 脚本已退出。${NC}"
    fi
    exit 0
}

echo -e "${GREEN}>>> 正在启动 Telegram-Name 全自动部署...${NC}"

# 1. 环境准备
PROJECT_DIR="/root/Telegram-Name"
[ ! -d "$PROJECT_DIR" ] && git clone https://github.com/xymn2023/Telegram-Name.git "$PROJECT_DIR"
cd "$PROJECT_DIR" || exit

# 2. 纯净安装
rm -rf venv api_auth.session
python3 -m venv venv
venv/bin/pip install --upgrade pip
venv/bin/pip install telethon emoji==1.7.0

# 3. 修复源码：静默警告 + 修复异步 + 替换API获取方式
sed -i '1i import warnings; warnings.filterwarnings("ignore"); import os' tg.py
sed -i 's/loop = asyncio.get_event_loop()/loop = asyncio.new_event_loop()/g' tg.py
sed -i '/asyncio.set_event_loop(loop)/d' tg.py
# 将原本的 input 逻辑替换为读取环境变量
sed -i "s/api_id = input('api_id: ')/api_id = int(os.getenv('TG_API_ID', 0))/g" tg.py
sed -i "s/api_hash = input('api_hash: ')/api_hash = os.getenv('TG_API_HASH', '')/g" tg.py

# 4. 【核心解决】强制等待用户输入
echo -e "${YELLOW}------------------------------------------------${NC}"
echo -e "${GREEN}请配置您的 API 参数 (必须手动输入)${NC}"

# < /dev/tty 强制 Bash 停下来等你的键盘
while true; do
    printf "${YELLOW}请输入 API ID (纯数字): ${NC}"
    read USER_ID < /dev/tty
    if [[ "$USER_ID" =~ ^[0-9]+$ ]]; then break; fi
    echo -e "${RED}输入错误！ID 必须是数字。${NC}"
done

while true; do
    printf "${YELLOW}请输入 API Hash: ${NC}"
    read USER_HASH < /dev/tty
    if [ -n "$USER_HASH" ]; then break; fi
    echo -e "${RED}Hash 不能为空。${NC}"
done

# 5. 注入环境变量并启动
export TG_API_ID=$USER_ID
export TG_API_HASH=$USER_HASH

trap ask_background SIGINT

echo -e "${GREEN}------------------------------------------------${NC}"
echo -e "${YELLOW}正在唤醒程序，请准备输入手机号进行验证。${NC}"
echo -e "完成登录后，看到时间更新，请按 ${RED}Ctrl+C${NC} 转入后台。"
echo -e "${GREEN}------------------------------------------------${NC}"

venv/bin/python3 tg.py
