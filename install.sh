#!/bin/bash

# --- 样式定义 ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# --- 信号处理函数 ---
function ask_background {
    echo -e "\n${YELLOW}>>> 检测到中断。${NC}"
    read -p "登录已完成？是否开启后台自动运行? (y/n): " confirm
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        pkill -f tg.py 2>/dev/null
        nohup /root/Telegram-Name/venv/bin/python3 /root/Telegram-Name/tg.py > /root/Telegram-Name/tg.log 2>&1 &
        echo $! > /root/Telegram-Name/tg.pid
        echo -e "${GREEN}>>> 已转入后台运行！PID: $(cat /root/Telegram-Name/tg.pid)${NC}"
        echo -e "${GREEN}>>> 日志查看: tail -f /root/Telegram-Name/tg.log${NC}"
    else
        echo -e "${RED}>>> 脚本已退出。${NC}"
    fi
    exit 0
}

echo -e "${GREEN}>>> 正在启动 Telegram-Name 全自动安全部署...${NC}"

# 1. 目录准备
PROJECT_DIR="/root/Telegram-Name"
if [ ! -d "$PROJECT_DIR" ]; then
    git clone https://github.com/xymn2023/Telegram-Name.git "$PROJECT_DIR"
fi
cd "$PROJECT_DIR" || exit

# 2. 环境纯净安装
rm -rf venv
rm -f api_auth.session
python3 -m venv venv
venv/bin/pip install --upgrade pip
venv/bin/pip install telethon emoji==1.7.0

# 3. 【关键改进】在 Bash 层阻塞获取输入，确保不为空且必须是数字
echo -e "${YELLOW}------------------------------------------------${NC}"
while true; do
    read -p "请输入您的 API ID (纯数字): " USER_ID
    if [[ "$USER_ID" =~ ^[0-9]+$ ]]; then break; fi
    echo -e "${RED}输入无效，API ID 必须是纯数字！${NC}"
done

while true; do
    read -p "请输入您的 API Hash: " USER_HASH
    if [[ -n "$USER_HASH" ]]; then break; fi
    echo -e "${RED}API Hash 不能为空！${NC}"
done
echo -e "${YELLOW}------------------------------------------------${NC}"

# 4. 修复 tg.py 异步逻辑，并强制重写 API 读取部分
# 使用 Python 脚本安全地重写 tg.py，避免 sed 乱码
venv/bin/python3 - <<EOF
import sys
import os

with open('tg.py', 'r') as f:
    lines = f.readlines()

new_lines = []
skip_old_input = False

# 插入警告屏蔽
new_lines.append("import warnings; warnings.filterwarnings('ignore')\n")
new_lines.append("import os\n")

for line in lines:
    # 修复异步启动
    line = line.replace('asyncio.get_event_loop()', 'asyncio.new_event_loop()')
    line = line.replace('asyncio.set_event_loop(loop)', '')
    
    # 替换 API 输入逻辑
    if "if not os.path.exists(api_auth_file+'.session'):" in line:
        new_lines.append("if True: # Modified by install script\n")
        new_lines.append("    api_id = int(os.getenv('TG_API_ID'))\n")
        new_lines.append("    api_hash = os.getenv('TG_API_HASH')\n")
        skip_old_input = True
        continue
    
    if skip_old_input:
        if "api_id =" in line or "api_hash =" in line or "else:" in line or "input(" in line:
            continue
        else:
            skip_old_input = False
    
    new_lines.append(line)

with open('tg.py', 'w') as f:
    f.writelines(new_lines)
EOF

# 5. 设置环境变量并启动
export TG_API_ID=$USER_ID
export TG_API_HASH=$USER_HASH

trap ask_background SIGINT

echo -e "${GREEN}>>> 正在唤醒程序，请准备输入手机号登录...${NC}"
venv/bin/python3 tg.py

# 正常退出也询问
ask_background
