#!/bin/bash

# --- 样式定义 ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# --- 信号处理函数 ---
# 当用户按下 Ctrl+C 时，执行此函数
function ask_background {
    echo -e "\n${YELLOW}>>> 检测到中断信号。${NC}"
    read -p "配置是否已完成？是否开启后台自动运行? (y/n): " confirm
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        pkill -f tg.py 2>/dev/null
        nohup venv/bin/python3 tg.py > tg.log 2>&1 &
        echo $! > tg.pid
        echo -e "${GREEN}>>> 已转入后台运行！PID: $(cat tg.pid)${NC}"
        echo -e "${GREEN}>>> 日志查看: tail -f tg.log${NC}"
    else
        echo -e "${RED}>>> 脚本已完全退出。${NC}"
    fi
    exit 0
}

echo -e "${GREEN}>>> 正在启动 Telegram-Name 全自动部署脚本${NC}"

# 1. 仓库处理
PROJECT_DIR="Telegram-Name"
if [ ! -d "$PROJECT_DIR" ]; then
    git clone https://github.com/xymn2023/Telegram-Name.git
fi
cd "$PROJECT_DIR" || exit

# 2. 清理环境
rm -rf venv
rm -f api_auth.session

# 3. 创建虚拟环境并安装依赖
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install telethon emoji==1.7.0

# 4. 自动修复源码兼容性
sed -i 's/loop = asyncio.get_event_loop()/loop = asyncio.new_event_loop()/g' tg.py
sed -i '/asyncio.set_event_loop(loop)/d' tg.py

# 5. 核心：设置捕获信号
# 告诉脚本：如果收到 SIGINT (Ctrl+C)，执行 ask_background 函数
trap ask_background SIGINT

# 6. 交互式启动
echo -e "${GREEN}------------------------------------------------${NC}"
echo -e "${RED}提示：请务必使用手机号登录。${NC}"
echo -e "${YELLOW}登录成功并看到 'Updated -> ...' 后，请按 Ctrl+C 唤起后台运行选项。${NC}"
echo -e "${GREEN}------------------------------------------------${NC}"

# 启动程序
python3 tg.py

# 如果程序自己正常结束了（没按 Ctrl+C），也触发一次询问
ask_background