#!/bin/bash
# 作業前必須使用量チェックスクリプト
# 全ての役割が作業開始前に実行する

ROLE="$1"
WORK_TYPE="$2"
USAGE_LOG="/tmp/autodev_status/claude_usage.log"
SHARED_DIR="/tmp/autodev_status"

if [ -z "$ROLE" ]; then
    echo "使用方法: ./scripts/check_usage_before_work.sh [ROLE] [WORK_TYPE]"
    echo "例: ./scripts/check_usage_before_work.sh Manager 要件定義作成"
    exit 1
fi

# 共有ディレクトリが存在しない場合は作成
mkdir -p "$SHARED_DIR"

# 現在時刻（日本時間）
JST_TIME=$(TZ=Asia/Tokyo date '+%Y-%m-%d %H:%M:%S JST')

# npx ccusageを実行して使用量を取得
get_usage_percentage() {
    echo "y" | npx ccusage@latest 2>/dev/null | grep -E "今日の使用量|Today's usage" | grep -oE '[0-9]+' | tail -1
}

# claude-monitorからの情報を取得
get_monitor_info() {
    if command -v claude-monitor >/dev/null 2>&1; then
        claude-monitor --timezone Asia/Tokyo --plan Pro 2>/dev/null | grep -E "使用率|Usage" | grep -oE '[0-9]+%' | head -1 | sed 's/%//'
    else
        echo "0"
    fi
}

# 使用量チェック関数
check_usage() {
    local current_usage=""
    local usage_source=""
    
    # まずnpx ccusageを試行
    current_usage=$(get_usage_percentage)
    if [ -n "$current_usage" ] && [ "$current_usage" -gt 0 ]; then
        usage_source="ccusage"
    else
        # ccusageが失敗した場合はclaude-monitorを使用
        current_usage=$(get_monitor_info)
        usage_source="claude-monitor"
    fi
    
    # ログに記録
    echo "[$JST_TIME] $ROLE作業前チェック: ${current_usage}% (source: $usage_source, work: $WORK_TYPE)" >> "$USAGE_LOG"
    
    echo "$current_usage"
}

# 復帰可能時間を計算
calculate_recovery_time() {
    local current_hour=$(TZ=Asia/Tokyo date +%H)
    local target_hour=2  # UTC 17:00 = JST 02:00
    
    if [ "$current_hour" -lt 2 ]; then
        # 今日の2時まで
        echo "今日 02:00 JST"
    else
        # 明日の2時まで
        echo "明日 02:00 JST"
    fi
}

# 85%チェック
is_usage_high() {
    local usage="$1"
    if [ -n "$usage" ] && [ "$usage" -ge 85 ]; then
        return 0  # true (使用量が高い)
    else
        return 1  # false (使用量は安全)
    fi
}

# Usage モニターに結果を即座に反映
update_usage_monitor() {
    local usage="$1"
    local status="$2"
    local role="$3"
    local work="$4"
    
    # 使用量モニターファイルを直接更新
    cat > /tmp/autodev_status/usage_check_result.txt << EOF
=== Claude使用量チェック結果 ===
📅 チェック時刻: $JST_TIME
🎯 実行役割: $role
📝 予定作業: $work
📊 現在使用量: ${usage}%
💡 判定結果: $status
================================
EOF
}

# メイン処理
main() {
    echo "📊 [$ROLE] 作業前使用量チェックを実行しています..."
    
    local current_usage=$(check_usage)
    
    if [ -z "$current_usage" ]; then
        echo "⚠️ 使用量を取得できませんでした。作業を続行します。"
        update_usage_monitor "不明" "取得失敗 - 作業続行" "$ROLE" "$WORK_TYPE"
        return 0
    fi
    
    echo "📊 現在のClaude使用量: ${current_usage}%"
    
    if is_usage_high "$current_usage"; then
        local recovery_time=$(calculate_recovery_time)
        echo "🚫 使用量が85%を超えています (${current_usage}%)。"
        echo "⏰ 復帰可能予測時間: $recovery_time"
        update_usage_monitor "$current_usage" "🚫 制限到達 - 待機必要" "$ROLE" "$WORK_TYPE"
        return 1  # 作業停止
    else
        echo "✅ 使用量は安全範囲内です (${current_usage}%)。作業を開始します。"
        update_usage_monitor "$current_usage" "✅ 安全 - 作業開始" "$ROLE" "$WORK_TYPE"
        return 0  # 作業継続
    fi
}

# スクリプトが直接実行された場合
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi