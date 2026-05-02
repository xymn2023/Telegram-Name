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
        echo -e "${GREEN}>>> 已转入后台。PID: $(cat /root/Telegram-Name/tg.pid)${NC}"
    fi
    exit 0
}

echo -e "${GREEN}>>> 正在启动 Telegram-Name 部署程序${NC}"

# 1. 环境准备
PROJECT_DIR="/root/Telegram-Name"
if [ ! -d "$PROJECT_DIR" ]; then
    git clone https://github.com/xymn2023/Telegram-Name.git "$PROJECT_DIR"
fi
cd "$PROJECT_DIR" || exit

# 2. 纯净安装
rm -rf venv
rm -f api_auth.session
python3 -m venv venv
venv/bin/pip install --upgrade pip
venv/bin/pip install telethon emoji==1.7.0

# 3. 源码修复 (仅限异步逻辑，不再改动输入逻辑)
sed -i 's/loop = asyncio.get_event_loop()/loop = asyncio.new_event_loop()/g' tg.py
sed -i '/asyncio.set_event_loop(loop)/d' tg.py

# 4. 【核心改进】在 Bash 层阻塞式获取输入，确保不为空
echo -e "${YELLOW}------------------------------------------------${NC}"
echo -e "${GREEN}请配置您的 Telegram API 参数 (从 my.telegram.org 获取)${NC}"

# 循环直到 api_id 是纯数字
while true; do
    read -p "请输入 API ID (纯数字): " USER_API_ID
    if [[ "$USER_API_ID" =~ ^[0-9]+$ ]]; then
        break
    else
        echo -e "${RED}错误：API ID 必须是纯数字，请重新输入。${NC}"
    fi
done

# 循环直到 api_hash 不为空
while true; do
    read -p "请输入 API Hash: " USER_API_HASH
    if [ -n "$USER_API_HASH" ]; then
        break
    else
        echo -e "${RED}错误：API Hash 不能为空。${NC}"
    fi
done

# 5. 自动生成一个简单的配置文件，强行覆盖 tg.py 的输入行为
# 我们通过 Python 的环境变量来注入这些值，避免修改源码产生的乱码
export TG_API_ID=$USER_API_ID
export TG_API_HASH=$USER_API_HASH

# 稍微修改 tg.py 让它优先读取环境变量（这一步非常安全）
sed -i "s/api_id = input('api_id: ')/api_id = os.getenv('TG_API_ID')/g" tg.py
sed -i "s/api_hash = input('api_hash: ')/api_hash = os.getenv('TG_API_HASH')/g" tg.py

# 6. 运行
trap ask_background SIGINT

echo -e "${GREEN}------------------------------------------------${NC}"
echo -e "${YELLOW}正在启动登录程序...${NC}"
echo -e "${YELLOW}请按照提示输入手机号、验证码。${NC}"
echo -e "${YELLOW}登录成功后，按 Ctrl+C 即可。${NC}"
echo -e "${GREEN}------------------------------------------------${NC}"

venv/bin/python3 tg.py
