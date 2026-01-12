#!/bin/bash
export LANG=en_US.UTF-8

# 1. 架构检测
case "$(uname -m)" in
	x86_64 | x64 | amd64 ) cpu=amd64 ;;
	i386 | i686 ) cpu=386 ;;
	armv8 | armv8l | arm64 | aarch64 ) cpu=arm64 ;;
	armv7l ) cpu=arm ;;
	* ) echo "暂不支持当前架构"; exit ;;
esac

# 2. 注入目标地区特定 IP 段 (核心改进：解决库里没人的问题)
# 这些网段涵盖了 Cloudflare 在亚太地区最活跃的 Anycast 节点
generate_ip_list() {
    cat > ips-v4.txt << EOF
1.0.0.0/24
1.1.1.0/24
103.21.244.0/22
103.22.200.0/22
104.16.0.0/12
108.162.192.0/18
141.101.64.0/18
162.158.0.0/15
172.64.0.0/13
188.114.96.0/20
190.93.240.0/20
197.234.240.0/22
198.41.128.0/17
EOF
    # IPV6 段（如果需要）
    cat > ips-v6.txt << EOF
2400:cb00::/32
2606:4700::/32
2803:f800::/32
2405:b500::/32
2405:8100::/32
2a06:98c0::/29
2c0f:f248::/32
EOF
}

# 3. 结果分类筛选函数 (核心改进：确保不被香港 IP 霸榜)
result(){
    echo "正在分类整理各地区节点..."
    # 新加坡
    awk -F ',' '$2 ~ /SIN/ {print $0}' $ip.csv | sort -t ',' -k5,5n | head -n 3 > SG-$ip.csv
    # 韩国
    awk -F ',' '$2 ~ /ICN/ {print $0}' $ip.csv | sort -t ',' -k5,5n | head -n 3 > KR-$ip.csv
    # 泰国
    awk -F ',' '$2 ~ /BKK/ {print $0}' $ip.csv | sort -t ',' -k5,5n | head -n 3 > TH-$ip.csv
    # 澳大利亚
    awk -F ',' '$2 ~ /SYD|MEL|BNE|ADL|PER/ {print $0}' $ip.csv | sort -t ',' -k5,5n | head -n 3 > AU-$ip.csv
    # 美国
    awk -F ',' '$2 ~ /LAX|SFO|SJC|SEA|PHX|ORD|EWR|IAD/ {print $0}' $ip.csv | sort -t ',' -k5,5n | head -n 3 > US-$ip.csv
    # 香港 (作为备选)
    awk -F ',' '$2 ~ /HKG/ {print $0}' $ip.csv | sort -t ',' -k5,5n | head -n 3 > HK-$ip.csv
}

# 4. 环境准备
if [ ! -e cf ]; then
    echo "下载测速工具..."
    curl -L -o cf -# --retry 2 --insecure https://raw.githubusercontent.com/yonggekkk/Cloudflare_vless_trojan/main/cf/$cpu
    chmod +x cf
fi

if [ ! -e locations.json ]; then
    curl -s -o locations.json https://raw.githubusercontent.com/yonggekkk/Cloudflare_vless_trojan/main/cf/locations.json
fi

# 5. 主菜单
echo "------------------------------------------------"
echo "Cloudflare 多地区优选脚本 (抽样加速版)"
echo "目标地区：新加坡、韩国、泰国、澳大利亚"
echo "------------------------------------------------"
echo "1、IPV4 优选"
echo "2、IPV6 优选"
echo "3、重置并退出"
read -p "请选择 [1-3]: " menu

if [ "$menu" = "1" ]; then
    ip=4
    generate_ip_list
    echo "开始快速抽样扫描 (预计 2-5 分钟)..."
    # -n 500 表示只取 500 个样本测速，防止时间过长
    ./cf -ips 4 -outfile 4.csv -n 500 -t 10
    result
elif [ "$menu" = "2" ]; then
    ip=6
    generate_ip_list
    ./cf -ips 6 -outfile 6.csv -n 500 -t 10
    result
elif [ "$menu" = "3" ]; then
    rm -rf *.csv locations.json ips-v4.txt ips-v6.txt cf
    exit
else
    exit
fi

# 6. 输出结果展示
clear
echo "================ 优选结果展示 ================"
for region in "SG:🇸🇬 新加坡" "KR:🇰🇷 韩国" "TH:🇹🇭 泰国" "AU:🇦🇺 澳大利亚" "HK:🇭🇰 香港" "US:🇺🇸 美国"
do
    code=${region%%:*}
    name=${region#*:}
    echo "[$name]"
    file="$code-$ip.csv"
    if [ -s "$file" ]; then
        cat "$file"
    else
        echo "未发现该地区有效节点 (可能被运营商劫持路由)"
    fi
    echo "----------------------------------------------"
done
