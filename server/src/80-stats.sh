#!/bin/bash
# 按终端显示宽度左对齐补齐(CJK 等宽字符按 2 列计),避免中文表头与数据错位
padl() {
    local s="$1" w="$2" i c len=0
    for ((i = 0; i < ${#s}; i++)); do
        c="${s:i:1}"
        if [ "$(printf '%d' "'${c}" 2>/dev/null)" -ge 128 ]; then
            len=$((len + 2))
        else
            len=$((len + 1))
        fi
    done
    printf '%s' "$s"
    while [ "${len}" -lt "${w}" ]; do
        printf ' '
        len=$((len + 1))
    done
}

# 活动连接表格行:9 列按显示宽度对齐
print_table_row() {
    padl "$1" 6; printf ' | '; padl "$2" 16; printf ' | '; padl "$3" 8; printf ' | '
    padl "$4" 5; printf ' | '; padl "$5" 9; printf ' | '; padl "$6" 9; printf ' | '
    padl "$7" 8; printf ' | '; padl "$8" 8; printf ' | '; padl "$9" 22; printf '\n'
}

format_bytes() {
    local bytes=$1
    if [ $bytes -lt 1024 ]; then
        echo "$(i18n unit_bytes ${bytes})"
    elif [ $bytes -lt $((1024 * 1024)) ]; then
        echo "$(i18n unit_kilobytes $(echo "scale=2; $bytes/1024" | bc))"
    elif [ $bytes -lt $((1024 * 1024 * 1024)) ]; then
        echo "$(i18n unit_megabytes $(echo "scale=2; $bytes/(1024*1024)" | bc))"
    else
        echo "$(i18n unit_gigabytes $(echo "scale=2; $bytes/(1024*1024*1024)" | bc))"
    fi
}

getHysteriaTrafic() {
    local api_port=$(getBackupValueOrDefault "/etc/hihy/conf/backup.yaml" "trafficPort" "")
    local secret=$(getYamlValue "/etc/hihy/conf/config.yaml" "auth.password" 2>/dev/null)

    # 未安装/配置缺失时 trafficPort 拿不到,直接报错而不是对着乱值发请求
    if ! isPositiveInt "${api_port}"; then
        echoColor red "$(i18n config_file_not_found)"
        return 1
    fi

    if [ -n "$secret" ]; then
        CURL_OPTS=(-H "Authorization: $secret")
    else
        CURL_OPTS=()
    fi

    echo "$(i18n traffic_server_status_title)"

    # 流量统计部分保持不变
    echoColor green "$(i18n traffic_stats_label)"
    # 用 yq 解析(脚本硬依赖):grep 正则对 JSON 的 { 转义/空白格式差异太脆弱,401/HTML 响应会被静默吞掉
    local traffic_resp traffic_out
    traffic_resp=$(curl -s "${CURL_OPTS[@]}" "http://127.0.0.1:${api_port}/traffic")
    if [ -n "${traffic_resp}" ]; then
        traffic_out=$(printf '%s' "${traffic_resp}" | yq -p json -o tsv 'to_entries[] | [.key, .value.tx, .value.rx] | @tsv' 2>/dev/null)
        if [ -n "${traffic_out}" ]; then
            while IFS=$'\t' read -r user tx rx; do
                tx_formatted=$(format_bytes "${tx}")
                rx_formatted=$(format_bytes "${rx}")
                # 模板占位符必须由 i18n 消费(外层 printf 再展开会把 %s 提前吞掉)
                printf '%s\n' "$(i18n traffic_stats_row "$user" "$tx_formatted" "$rx_formatted")"
            done <<<"${traffic_out}"
        else
            echoColor red "$(i18n traffic_api_error "${traffic_resp}")"
        fi
    fi

    # 在线用户部分保持不变
    echoColor green "\n$(i18n traffic_online_users_label)"
    local online_resp online_out
    online_resp=$(curl -s "${CURL_OPTS[@]}" "http://127.0.0.1:${api_port}/online")
    if [ -n "${online_resp}" ]; then
        online_out=$(printf '%s' "${online_resp}" | yq -p json -o tsv 'to_entries[] | [.key, .value] | @tsv' 2>/dev/null)
        if [ -n "${online_out}" ]; then
            while IFS=$'\t' read -r user count; do
                printf '%s\n' "$(i18n traffic_online_users_row "$user" "$count")"
            done <<<"${online_out}"
        else
            echoColor red "$(i18n traffic_api_error "${online_resp}")"
        fi
    fi

    echoColor green "\n$(i18n traffic_active_connections_label)"
    STREAMS_OUTPUT=$(curl -s "${CURL_OPTS[@]}" -H "Accept: text/plain" "http://127.0.0.1:${api_port}/dump/streams")

    if [ "$(echo "$STREAMS_OUTPUT" | wc -l)" -le 1 ]; then
        echo "$(i18n traffic_no_active_connections)"
    else
        # 打印表头
        local _h_state _h_user _h_conn_id _h_flows _h_up _h_down _h_alive _h_last_active _h_target_addr
        _h_state="$(i18n traffic_header_state)"
        _h_user="$(i18n traffic_header_user)"
        _h_conn_id="$(i18n traffic_header_conn_id)"
        _h_flows="$(i18n traffic_header_flows)"
        _h_up="$(i18n traffic_header_upload)"
        _h_down="$(i18n traffic_header_download)"
        _h_alive="$(i18n traffic_header_alive_time)"
        _h_last_active="$(i18n traffic_header_last_active)"
        _h_target_addr="$(i18n traffic_header_target_address)"
        print_table_row "$_h_state" "$_h_user" "$_h_conn_id" "$_h_flows" "$_h_up" "$_h_down" "$_h_alive" "$_h_last_active" "$_h_target_addr"
        echo "------|----------------|--------|-----|---------|---------|--------|--------|----------------------"

        # 使用临时文件存储排序数据
        temp_file=$(mktemp)

        echo "$STREAMS_OUTPUT" | awk \
            -v estab="$(i18n traffic_status_estab)" \
            -v closed="$(i18n traffic_status_closed)" \
            -v byte_suffix="$(i18n unit_byte_literal)" \
            -v kb_suffix="$(i18n unit_kilobyte_literal)" \
            -v mb_suffix="$(i18n unit_megabyte_literal)" \
            -v gb_suffix="$(i18n unit_gigabyte_literal)" \
            -v ms_suffix="$(i18n unit_millisecond_literal)" \
            -v s_suffix="$(i18n unit_second_literal)" \
            -v m_suffix="$(i18n unit_minute_literal)" \
            -v h_suffix="$(i18n unit_hour_literal)" \
            'BEGIN {
            status["ESTAB"]=estab
            status["CLOSED"]=closed
        }

        function format_bytes(bytes) {
            if (bytes < 1024) return bytes byte_suffix
            if (bytes < 1024*1024) return sprintf("%.2f%s", bytes/1024, kb_suffix)
            if (bytes < 1024*1024*1024) return sprintf("%.2f%s", bytes/(1024*1024), mb_suffix)
            return sprintf("%.2f%s", bytes/(1024*1024*1024), gb_suffix)
        }

        function format_time(time) {
            if (time == "-") return 0
            if (index(time, "ms") > 0) {
                gsub("ms", "", time)
                return time/1000
            }
            if (index(time, "s") > 0) {
                gsub("s", "", time)
                return time
            }
            if (index(time, "m") > 0) {
                gsub("m", "", time)
                return time * 60
            }
            if (index(time, "h") > 0) {
                gsub("h", "", time)
                return time * 3600
            }
            return time
        }

        function format_time_display(seconds) {
            if (seconds < 1) return sprintf("%.0f%s", seconds * 1000, ms_suffix)
            if (seconds < 60) return sprintf("%.1f%s", seconds, s_suffix)
            if (seconds < 3600) return sprintf("%.1f%s", seconds/60, m_suffix)
            return sprintf("%.1f%s", seconds/3600, h_suffix)
        }

        NR > 1 {
            last_active = format_time($8)
            # 第9列 Req-Addr 即客户端请求的目标地址;第10列 Hooked-Req-Addr 仅在 SNI 改写时非空,略去
            printf "%s|%s|%s|%s|%s|%s|%s|%.2f|%s\n", \
                status[$1], $2, $3, $4, \
                format_bytes($5), format_bytes($6), \
                format_time_display(format_time($7)), \
                last_active, \
                $9
        }' | sort -t'|' -k8,8nr >"$temp_file"

        # 读取排序后的数据并格式化输出
        while IFS='|' read -r state user conn_id flows up down alive last_active target_addr; do
            print_table_row "$state" "$user" "$conn_id" "$flows" "$up" "$down" \
                "$alive" "$(format_time_display "$last_active")" "$target_addr"
        done <"$temp_file"

        rm -f "$temp_file"
    fi

    echo "$(i18n traffic_separator_line)"
}

# 辅助函数：格式化时间显示
format_time_display() {
    local seconds=$1

    # 处理毫秒级别
    if (($(echo "$seconds < 1" | bc -l))); then
        printf "$(i18n unit_milliseconds $(echo "$seconds * 1000" | bc -l))"
        return
    fi

    # 处理秒级别
    if (($(echo "$seconds < 60" | bc -l))); then
        printf "$(i18n unit_seconds $seconds)"
        return
    fi

    # 处理分钟级别
    if (($(echo "$seconds < 3600" | bc -l))); then
        local minutes=$(echo "$seconds / 60" | bc -l)
        printf "$(i18n unit_minutes $minutes)"
        return
    fi

    # 处理小时级别
    local hours=$(echo "$seconds / 3600" | bc -l)
    # 如果小时数小于0.1，显示为分钟
    if (($(echo "$hours < 0.1" | bc -l))); then
        local minutes=$(echo "$seconds / 60" | bc -l)
        printf "$(i18n unit_minutes $minutes)"
    else
        printf "$(i18n unit_hours $hours)"
    fi
}

