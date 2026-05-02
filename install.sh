#!/bin/bash

# --- 颜色定义 ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# --- 确保脚本在 /root/Telegram-Name 目录下运行 ---
PROJECT_DIR="/root/Telegram-Name"

# 1. 环境初始化
echo -e "${GREEN}>>> 正在准备环境...${NC}"
if [ ! -d "$PROJECT_DIR" ]; then
    git clone https://github.com/xymn2023/Telegram-Name.git "$PROJECT_DIR"
fi
cd "$PROJECT_DIR" || exit

# 2. 纯净安装依赖
rm -rf venv api_auth.session
python3 -m venv venv
./venv/bin/pip install --upgrade pip
./venv/bin/pip install telethon emoji==1.7.0

# 3. 源码静默与异步修复 (不改动输入逻辑，仅修复兼容性)
sed -i '1i import warnings; warnings.filterwarnings("ignore"); import os' tg.py
sed -i 's/loop = asyncio.get_event_loop()/loop = asyncio.new_event_loop()/g' tg.py
sed -i '/asyncio.set_event_loop(loop)/d' tg.py
# 将源码中的 input 替换为读取系统环境变量，防止输入流冲突
sed -i "s/api_id = input('api_id: ')/api_id = int(os.getenv('TG_API_ID', 0))/g" tg.py
sed -i "s/api_hash = input('api_hash: ')/api_hash = os.getenv('TG_API_HASH', '')/g" tg.py

# 4. 【强制等待】获取用户输入
echo -e "${YELLOW}------------------------------------------------${NC}"
echo -e "${GREEN}请输入您的 API 参数 (必须手动键盘输入)${NC}"

# 使用 /dev/tty 确保在管道运行模式下也能阻塞等待键盘
while true; do
    printf "${YELLOW}请输入 API ID (纯数字): ${NC}"
    read -r USER_ID < /dev/tty
    if [[ "$USER_ID" =~ ^[0-9]+$ ]]; then break; fi
    echo -e "${RED}输入错误！ID必须是数字。${NC}"
done

while true; do
    printf "${YELLOW}请输入 API Hash: ${NC}"
    read -r USER_HASH < /dev/tty
    if [ -n "$USER_HASH" ]; then break; fi
    echo -e "${RED}Hash 不能为空。${NC}"
done

export TG_API_ID=$USER_ID
export TG_API_HASH=$USER_HASH

# 5. 【核心修复】运行并捕获中断
echo -e "${GREEN}------------------------------------------------${NC}"
echo -e "${YELLOW}启动登录程序。成功登录后，请务必按 Ctrl+C 来触发后台运行选项。${NC}"
echo -e "${GREEN}------------------------------------------------${NC}"

# 执行 Python 程序，并允许它接收 Ctrl+C
./venv/bin/python3 tg.py

# --- 关键：无论 Python 是正常退出还是被 Ctrl+C，都会执行到这里 ---
echo -e "\n${YELLOW}>>> 检测到主程序已停止。${NC}"
while true; do
    printf "${GREEN}是否现在开启后台自动运行? (y/n): ${NC}"
    read -r confirm < /dev/tty
    case $confirm in
        [Yy]* )
            pkill -f tg.py 2>/dev/null
            nohup "$PROJECT_DIR/venv/bin/python3" "$PROJECT_DIR/tg.py" > "$PROJECT_DIR/tg.log" 2>&1 &
            echo $! > "$PROJECT_DIR/tg.pid"
            echo -e "${GREEN}>>> 已成功转入后台运行！${NC}"
            echo -e "${GREEN}>>> 查看日志命令: tail -f $PROJECT_DIR/tg.log${NC}"
            break
            ;;
        [Nn]* )
            echo -e "${RED}>>> 脚本已退出，未启动后台。${NC}"
            break
            ;;
        * ) echo "请输入 y 或 n。";;
    esac
done
