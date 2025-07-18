#!/bin/bash
# Claude使用量チェックスクリプト
# Managerが作業前に使用量を確認し、85%を超えている場合は待機

USAGE_LOG="/tmp/autodev_status/claude_usage.log"
SHARED_DIR="/tmp/autodev_status"

# 共有ディレクトリが存在しない場合は作成
mkdir -p "$SHARED_DIR"

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
    echo "$(date '+%Y-%m-%d %H:%M:%S') - 使用量: ${current_usage}% (source: $usage_source)" >> "$USAGE_LOG"
    
    echo "$current_usage"
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

# リセット時間チェック (UTC 17:00 = JST 02:00)
is_reset_time() {
    local current_hour=$(date -u +%H)
    if [ "$current_hour" -eq 17 ]; then
        return 0  # true (リセット時間)
    else
        return 1  # false (リセット時間ではない)
    fi
}

# 待機モード
wait_for_reset() {
    echo "⚠️ Claude使用量が85%を超えています。リセット時間まで待機します..."
    
    # 進捗表示を待機モードに更新
    /workspace/Demo/scripts/update_progress_status.sh "Manager" "使用量上限により待機中... (UTC 17:00まで)" "待機" >/dev/null 2>&1
    
    while true; do
        sleep 300  # 5分間隔でチェック
        
        if is_reset_time; then
            echo "🔄 リセット時間になりました。使用量を再確認します..."
            local new_usage=$(check_usage)
            
            if ! is_usage_high "$new_usage"; then
                echo "✅ 使用量がリセットされました (${new_usage}%)。作業を再開します。"
                return 0
            fi
        fi
        
        echo "⏰ まだ待機中... $(date '+%H:%M:%S')"
    done
}

# メイン処理
main() {
    local current_usage=$(check_usage)
    
    if [ -z "$current_usage" ]; then
        echo "⚠️ 使用量を取得できませんでした。作業を続行します。"
        return 0
    fi
    
    echo "📊 現在のClaude使用量: ${current_usage}%"
    
    if is_usage_high "$current_usage"; then
        echo "🚫 使用量が85%を超えています (${current_usage}%)。"
        wait_for_reset
    else
        echo "✅ 使用量は安全範囲内です (${current_usage}%)。作業を開始します。"
    fi
    
    return 0
}

# スクリプトが直接実行された場合
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi