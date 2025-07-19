#!/bin/bash
# 作業前必須使用量チェックスクリプト
# 全ての役割が作業開始前に実行する

ROLE="$1"
WORK_TYPE="$2"
USAGE_LOG="/tmp/autodevg_status/claude_usage.log"
SHARED_DIR="/tmp/autodevg_status"

# 設定
WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}").." && pwd)"
CHECK_CLAUDE_USAGE="$WORKSPACE_DIR/scripts/check_claude_usage.sh"

if [ -z "$ROLE" ]; then
    echo "使用方法: ./scripts/check_usage_before_work.sh [ROLE] [WORK_TYPE]"
    echo "例: ./scripts/check_usage_before_work.sh Manager 要件定義作成"
    exit 1
fi

# 共有ディレクトリが存在しない場合は作成
mkdir -p "$SHARED_DIR"

# 現在時刻（日本時間）
JST_TIME=$(TZ=Asia/Tokyo date '+%Y-%m-%d %H:%M:%S JST')

# 使用量に応じた段階的スリープ時間を計算
calculate_sleep_time() {
    local usage="$1"
    local base_sleep=10  # デフォルト10秒
    
    if [ -z "$usage" ] || [ "$usage" -eq 0 ]; then
        echo "$base_sleep"
    elif [ "$usage" -ge 80 ]; then
        echo $((base_sleep + 30))  # 40秒
    elif [ "$usage" -ge 70 ]; then
        echo $((base_sleep + 20))  # 30秒
    elif [ "$usage" -ge 60 ]; then
        echo $((base_sleep + 10))  # 20秒
    else
        echo "$base_sleep"  # 10秒
    fi
}

# 使用量チェック関数
check_usage() {
    # check_claude_usage.shを使用して使用量を取得
    if [ -f "$CHECK_CLAUDE_USAGE" ]; then
        local usage_output=$("$CHECK_CLAUDE_USAGE" 2>&1)
        local current_usage=$(echo "$usage_output" | grep -E "現在のClaude使用量:" | grep -oE '[0-9]+' | head -1)
        
        if [ -n "$current_usage" ]; then
            echo "$current_usage"
        else
            echo "0"
        fi
    else
        echo "0"
    fi
}

# 復帰可能時間を計算（max5プラン対応）
calculate_recovery_time() {
    # max5プランは5時間ごとのリセットなので、セッション開始時刻から計算
    local start_time_file="$SHARED_DIR/session_start_time.txt"
    
    if [ -f "$start_time_file" ]; then
        local start_time=$(cat "$start_time_file")
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        local reset_interval=$((5 * 3600))  # 5時間
        local remaining=$((reset_interval - (elapsed % reset_interval)))
        local hours=$((remaining / 3600))
        local minutes=$(((remaining % 3600) / 60))
        echo "${hours}時間${minutes}分後"
    else
        echo "不明"
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
    cat > /tmp/autodevg_status/usage_check_result.txt << EOF
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
    
    if [ -z "$current_usage" ] || [ "$current_usage" -eq 0 ]; then
        echo "⚠️ 使用量を取得できませんでした。安全のため10秒待機後、作業を続行します。"
        update_usage_monitor "不明" "取得失敗 - 10秒待機後続行" "$ROLE" "$WORK_TYPE"
        sleep 10
        return 0
    fi
    
    echo "📊 現在のClaude使用量: ${current_usage}%"
    
    # 段階的スリープ時間を計算
    local sleep_time=$(calculate_sleep_time "$current_usage")
    
    if is_usage_high "$current_usage"; then
        # 85%以上の場合は待機モードへ
        local recovery_time=$(calculate_recovery_time)
        echo "🚫 使用量が85%を超えています (${current_usage}%)。"
        echo "⏰ 復帰可能予測時間: $recovery_time"
        echo "⏳ 待機モードに入ります..."
        update_usage_monitor "$current_usage" "🚫 制限到達 - 待機モード" "$ROLE" "$WORK_TYPE"
        
        # check_claude_usage.shの待機機能を呼び出す
        "$CHECK_CLAUDE_USAGE"
        return $?
    else
        # 85%未満の場合は段階的スリープ後に作業開始
        echo "✅ 使用量は安全範囲内です (${current_usage}%)。"
        echo "⏳ ${sleep_time}秒待機してから作業を開始します..."
        update_usage_monitor "$current_usage" "✅ 安全 - ${sleep_time}秒待機後作業開始" "$ROLE" "$WORK_TYPE"
        sleep "$sleep_time"
        echo "🚀 [$ROLE] 作業を開始します: $WORK_TYPE"
        return 0
    fi
}

# スクリプトが直接実行された場合
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi