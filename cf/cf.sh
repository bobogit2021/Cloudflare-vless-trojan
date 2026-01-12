#!/bin/bash
export LANG=en_US.UTF-8

# 1. 生成移动专供 IP 库 (包含 IPv4 冷门段和 IPv6 亚太全量段)
generate_ip_lists() {
    # IPv4：加入了一些容易跳出非香港节点的冷门 CMI 网段
    cat > ips-v4.txt << EOF
1.0.0.0/24
188.114.96.0/20
141.101.64.0/18
104.16.0.0/13
172.64.0.0/13
103.21.244.0/22
190.93.240.0/20
EOF

    # IPv6：移动线路在 IPv6 下极易直连新加坡、日本和韩国
    cat > ips-v6.txt << EOF
2400:cb00::/32
2606:4700::/32
2405:b500::/32
2405:8100::/32
2a06:98c0::/29
2c0f:f248::/32
EOF
}

# 2. 深度分类函数 (针对你要求的四个地区 + 香港/美国)
result(){
    # 定义分类列表：新加坡、韩国(含日本)、泰国、澳大利亚、美国、香港
    echo "正在对 $1 结果进行深度分类..."
    awk -F ',' '$2 ~ /SIN/ {print $0}' $1.csv | sort -t ',' -k5,5n | head -n 3 > SG-$1.csv
    awk -F ',' '$2 ~ /ICN|NRT|HND|KIX/ {print $0}' $1.csv | sort -t ',' -k5,5n | head -n 3 > KRJP-$1.csv
    awk -F ',' '$2 ~ /BKK/ {print $0}' $1.csv | sort -t ',' -k5,5n | head -n 3 > TH-$1.csv
    awk -F ',' '$2 ~ /SYD|MEL|BNE|ADL|PER/ {print $0}' $1.csv | sort -t ',' -k5,5n | head -n 3 > AU-$1.csv
    awk -F ',' '$2 ~ /HKG/ {print $0}' $1.csv | sort -t ',' -k5,5n | head -n 3 > HK-$1.csv
    awk -F ',' '$2 ~ /LAX|SFO|SJC|SEA|ORD|EWR|IAD/ {print $0}' $1.csv | sort -t ',' -k5,5n | head -n 3 > US-$1.csv
}

# 3. 结果展示函数
show_result() {
    type=$1
    echo "================ $type 优选结果汇总 ================"
    for region in "SG:🇸🇬 新加坡" "KRJP:🇰🇷🇯🇵 韩日" "TH:🇹🇭 泰国" "AU:🇦🇺 澳大利亚" "HK:🇭🇰 香港" "US:🇺🇸 美国"
    do
        code=${region%%:*}
        name=${region#*:}
        file="$code-$type.csv"
        echo "[$name]"
        if [ -s "$file" ]; then
            cat "$file"
        else
            echo "未发现直连节点 (此线路该地区可能绕路)"
        fi
        echo "------------------------------------------------"
    done
}

# 4. 主程序执行逻辑
clear
echo "正在检测环境..."
generate_ip_lists

# 探测 IPv6 是否可用
if ping6 -c 1 2400:3200::1 &> /dev/null; then
    ipv6_ready=true
    echo "检测到 IPv6 环境可用。"
else
    ipv6_ready=false
    echo "未检测到 IPv6 环境，将仅优选 IPv4。"
fi

# 开始优选 IPv4
echo "正在优选 IPv4 (样本量 800)..."
./cf -ips 4 -outfile 4.csv -n 800 -task 100
result 4

# 如果有 IPv6，开始优选 IPv6
if [ "$ipv6_ready" = true ]; then
    echo "正在优选 IPv6 (样本量 800)..."
    ./cf -ips 6 -outfile 6.csv -n 800 -task 100
    result 6
fi

# 5. 打印最终报告
clear
show_result 4
if [ "$ipv6_ready" = true ]; then
    show_result 6
fi

