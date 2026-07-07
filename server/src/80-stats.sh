#!/bin/bash
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
    local api_port=$(getYamlValue "/etc/hihy/conf/backup.yaml" "trafficPort")
    local secret=$(getYamlValue "/etc/hihy/conf/config.yaml" "auth.password")

    if [ -n "$secret" ]; then
        CURL_OPTS=(-H "Authorization: $secret")
    else
        CURL_OPTS=()
    fi

    echo "$(i18n traffic_server_status_title)"

    # 流量统计部分保持不变
    echoColor green "$(i18n traffic_stats_label)"
    curl -s "${CURL_OPTS[@]}" "http://127.0.0.1:${api_port}/traffic" \
        | grep -oE '"[^"]+":{"tx":[0-9]+,"rx":[0-9]+}' \
        | while IFS=: read -r user stats; do
            tx=$(echo $stats | grep -oE '"tx":[0-9]+' | cut -d: -f2)
            rx=$(echo $stats | grep -oE '"rx":[0-9]+' | cut -d: -f2)
            user=$(echo $user | tr -d '"')
            tx_formatted=$(format_bytes $tx)
            rx_formatted=$(format_bytes $rx)
            printf "$(i18n traffic_stats_row)\n" "$user" "$tx_formatted" "$rx_formatted"
        done

    # 在线用户部分保持不变
    echoColor green "\n$(i18n traffic_online_users_label)"
    curl -s "${CURL_OPTS[@]}" "http://127.0.0.1:${api_port}/online" \
        | grep -oE '"[^"]+":[0-9]+' \
        | while IFS=: read -r user count; do
            user=$(echo $user | tr -d '"')
            count=$(echo $count | tr -d ' ')
            printf "$(i18n traffic_online_users_row)\n" "$user" "$count"
        done

    echoColor green "\n$(i18n traffic_active_connections_label)"
    STREAMS_OUTPUT=$(curl -s "${CURL_OPTS[@]}" -H "Accept: text/plain" "http://127.0.0.1:${api_port}/dump/streams")

    if [ "$(echo "$STREAMS_OUTPUT" | wc -l)" -le 1 ]; then
        echo "$(i18n traffic_no_active_connections)"
    else
        # 打印表头
        local _h_state _h_user _h_conn_id _h_flows _h_up _h_down _h_alive _h_last_active _h_req_addr _h_target_addr
        _h_state="$(i18n traffic_header_state)"
        _h_user="$(i18n traffic_header_user)"
        _h_conn_id="$(i18n traffic_header_conn_id)"
        _h_flows="$(i18n traffic_header_flows)"
        _h_up="$(i18n traffic_header_upload)"
        _h_down="$(i18n traffic_header_download)"
        _h_alive="$(i18n traffic_header_alive_time)"
        _h_last_active="$(i18n traffic_header_last_active)"
        _h_req_addr="$(i18n traffic_header_request_address)"
        _h_target_addr="$(i18n traffic_header_target_address)"
        printf "%-8s | %-15s | %-10s | %-3s | %-10s | %-10s | %-12s | %-12s | %-20s | %-20s\n" \
            "$_h_state" "$_h_user" "$_h_conn_id" "$_h_flows" "$_h_up" "$_h_down" "$_h_alive" "$_h_last_active" "$_h_req_addr" "$_h_target_addr"
        echo "----------|-----------------|------------|------|------------|------------|--------------|--------------|----------------------|----------------------"

        # 使用临时文件存储排序数据
        temp_file=$(mktemp)

        echo "$STREAMS_OUTPUT" | awk -v estab="$(i18n traffic_status_estab)" \
            -v closed="$(i18n traffic_status_closed)" \
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
            printf "%s|%s|%s|%s|%s|%s|%s|%.2f|%s|%s\n", \
                status[$1], $2, $3, $4, \
                format_bytes($5), format_bytes($6), \
                format_time_display(format_time($7)), \
                last_active, \
                $9, $10
        }' -v byte_suffix="$(i18n unit_byte_literal)" \
            -v kb_suffix="$(i18n unit_kilobyte_literal)" \
            -v mb_suffix="$(i18n unit_megabyte_literal)" \
            -v gb_suffix="$(i18n unit_gigabyte_literal)" \
            -v ms_suffix="$(i18n unit_millisecond_literal)" \
            -v s_suffix="$(i18n unit_second_literal)" \
            -v m_suffix="$(i18n unit_minute_literal)" \
            -v h_suffix="$(i18n unit_hour_literal)" \
            | sort -t'|' -k8,8nr >"$temp_file"

        # 读取排序后的数据并格式化输出
        while IFS='|' read -r state user conn_id flows up down alive last_active req_addr target_addr; do
            printf "%-8s | %-15s | %-10s | %-3s | %-10s | %-10s | %-12s | %-12s | %-20s | %-20s\n" \
                "$state" "$user" "$conn_id" "$flows" "$up" "$down" \
                "$alive" "$(format_time_display $last_active)" "$req_addr" "$target_addr"
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

