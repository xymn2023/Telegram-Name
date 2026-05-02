#!/bin/bash

# --- 样式定义 ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# --- 信号处理函数 ---
function ask_background {
    echo -e "\n${YELLOW}>>> 检测到操作完成或中断。${NC}"
    read -p "配置是否已完成？是否开启后台自动运行? (y/n): " confirm
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        pkill -f tg.py 2>/dev/null
        # 即使退出脚本，也使用虚拟环境的 python 绝对路径启动
        nohup /root/Telegram-Name/venv/bin/python3 /root/Telegram-Name/tg.py > /root/Telegram-Name/tg.log 2>&1 &
        echo $! > /root/Telegram-Name/tg.pid
        echo -e "${GREEN}>>> 已转入后台运行！PID: $(cat /root/Telegram-Name/tg.pid)${NC}"
        echo -e "${GREEN}>>> 日志查看命令: tail -f /root/Telegram-Name/tg.log${NC}"
    else
        echo -e "${RED}>>> 脚本已完全退出。${NC}"
    fi
    exit 0
}

echo -e "${GREEN}>>> 开始 Telegram-Name 部署与环境加固...${NC}"

# 1. 目录处理
PROJECT_DIR="/root/Telegram-Name"
if [ ! -d "$PROJECT_DIR" ]; then
    git clone https://github.com/xymn2023/Telegram-Name.git "$PROJECT_DIR"
fi
cd "$PROJECT_DIR" || exit

# 2. 彻底清理环境
rm -rf venv
rm -f api_auth.session

# 3. 创建虚拟环境并安装依赖
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install telethon emoji==1.7.0

# 4. 自动修复源码：增加警告静默 + 异步修复 + 输入校验
echo -e "${YELLOW}>>> 正在对 tg.py 进行深度优化...${NC}"

# 禁用所有警告 (DeprecationWarning)
sed -i '1i import warnings; warnings.filterwarnings("ignore", category=DeprecationWarning)' tg.py

# 异步启动修复
sed -i 's/loop = asyncio.get_event_loop()/loop = asyncio.new_event_loop()/g' tg.py
sed -i '/asyncio.set_event_loop(loop)/d' tg.py

# 强制要求输入 API ID/HASH (防止回车跳过)
# 我们用一段新的 Python 逻辑替换旧的输入逻辑
python3 - <<EOF
import sys
content = open('tg.py').read()
old_logic = """if not os.path.exists(api_auth_file+'.session'):
    api_id = input('api_id: ')
    api_hash = input('api_hash: ')"""
new_logic = """if not os.path.exists(api_auth_file+'.session'):
    api_id = ""
    while not api_id: api_id = input('请输入正确的 api_id: ').strip()
    api_hash = ""
    while not api_hash: api_hash = input('请输入正确的 api_hash: ').strip()"""
with open('tg.py', 'w') as f:
    f.write(content.replace(old_logic, new_logic))
EOF

# 5. 设置捕获信号
trap ask_background SIGINT

# 6. 交互式启动
echo -e "${GREEN}------------------------------------------------${NC}"
echo -e "${RED}重要提示：${NC}"
echo -e "1. 脚本会循环询问直到你输入有效的 API ID 和 Hash。"
echo -e "2. 登录请使用【手机号】，不要用 Bot Token。"
echo -e "3. 看到 'Updated -> ...' 后按 ${YELLOW}Ctrl+C${NC} 弹出后台选项。"
echo -e "${GREEN}------------------------------------------------${NC}"

# 启动程序
python3 tg.py

# 正常退出也触发询问
ask_background
