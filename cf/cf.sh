#!/bin/bash
export LANG=en_US.UTF-8

# 1. 架构检测
case "$(uname -m)" in
	x86_64 | x64 | amd64 ) cpu=amd64 ;;
	armv8 | armv8l | arm64 | aarch64 ) cpu=arm64 ;;
	* ) cpu=amd64 ;; # 默认 amd64
esac

# 2. 注入移动网络最容易直连亚洲的 IP 段
generate_ip_list() {
    cat > ips-v4.txt << EOF
188.114.96.0/20
141.101.64.0/18
104.16.0.0/12
172.64.0.0/13
1.0.0.0/24
1.1.1.0/24
103.21.244.0/22
162.158.0.0/15
EOF
}

# 3. 结果分类筛选函数 (增加更多亚洲节点识别)
result(){
    echo "正在深度筛选移动直连节点..."
    # 新加坡 (移动最爱)
    awk -F ',' '$2 ~ /SIN/ {print $0}' $ip.csv | sort -t ',' -k5,5n | head -n 3 > SG-$ip.csv
    # 泰国 (移动 CMI 特色)
    awk -F ',' '$2 ~ /BKK/ {print $0}' $ip.csv | sort -t ',' -k5,5n | head -n 3 > TH-$ip.csv
    # 韩国/日本
    awk -F ',' '$2 ~ /ICN|NRT|HND|KIX/ {print $0}' $ip.csv | sort -t ',' -k5,5n | head -n 3 > JP-KR-$ip.csv
    # 澳大利亚
    awk -F ',' '$2 ~ /SYD|MEL|BNE/ {print $0}' $ip.csv | sort -t ',' -k5,5n | head -n 3 > AU-$ip.csv
    # 香港
    awk -F ',' '$2 ~ /HKG/ {print $0}' $ip.csv | sort -t ',' -k5,5n | head -n 3 > HK-$ip.csv
}

# 4. 环境准备
[ ! -e cf ] && curl -L -o cf https://raw.githubusercontent.com/yonggekkk/Cloudflare_vless_trojan/main/cf/$cpu && chmod +x cf
[ ! -e locations.json ] && curl -s -o locations.json https://raw.githubusercontent.com/yonggekkk/Cloudflare_vless_trojan/main/cf/locations.json

# 5. 执行优选
clear
echo "------------------------------------------------"
echo "移动网络 (China Mobile) 深度优选版"
echo "尝试绕过香港，直连新加坡/泰国/韩国"
echo "------------------------------------------------"
generate_ip_list
ip=4

# 核心修改：使用 8080 端口，增加样本量到 1000
echo "开始探测 (使用 8080 端口，样本量 1000)..."
./cf -ips 4 -outfile 4.csv -n 1000 -t 15 -tp 8080

result

# 6. 输出结果展示
clear
echo "================ 移动网络优选结果 ================"
for region in "SG:🇸🇬 新加坡" "TH:🇹🇭 泰国" "JP-KR:🇯🇵🇰🇷 日韩" "AU:🇦🇺 澳大利亚" "HK:🇭🇰 香港"
do
    code=${region%%:*}
    name=${region#*:}
    echo "[$name]"
    file="$code-4.csv"
    if [ -s "$file" ]; then
        cat "$file"
    else
        echo "未发现该地区直连节点 (移动线路当前可能在维护或绕路)"
    fi
    echo "----------------------------------------------"
done
