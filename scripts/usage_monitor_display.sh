#!/bin/bash
# Claude使用量表示モニター
# 人間が理解しやすい形で現在の使用量とステータスを表示

USAGE_LOG="/tmp/autodevg_status/claude_usage.log"
SHARED_DIR="/tmp/autodevg_status"

# 共有ディレクトリが存在しない場合は作成
mkdir -p "$SHARED_DIR"

# 最新の使用量を取得
get_latest_usage() {
    if [ -f "$USAGE_LOG" ]; then
        tail -1 "$USAGE_LOG" | grep -oE '[0-9]+%' | sed 's/%//' || echo "0"
    else
        echo "0"
    fi
}

# 使用量状況の表示
display_usage_status() {
    local usage="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    printf "\n=== Claude使用量モニター ===\n"
    printf "📅 更新時刻: %s\n" "$(TZ=Asia/Tokyo date '+%Y-%m-%d %H:%M:%S JST')"
    
    if [ -z "$usage" ] || [ "$usage" -eq 0 ]; then
        printf "⚠️  使用量: データなし\n"
        printf "💡 状態: 初回チェック待ち\n"
    elif [ "$usage" -lt 50 ]; then
        printf "✅ 使用量: %d%% (安全)\n" "$usage"
        printf "💚 状態: 正常動作中\n"
    elif [ "$usage" -lt 75 ]; then
        printf "⚠️  使用量: %d%% (注意)\n" "$usage"
        printf "💛 状態: 使用量やや高め\n"
    elif [ "$usage" -lt 85 ]; then
        printf "🔶 使用量: %d%% (警告)\n" "$usage"
        printf "🧡 状態: 間もなく制限に到達\n"
    else
        printf "🚫 使用量: %d%% (制限)\n" "$usage"
        printf "❤️  状態: 待機モード (UTC 17:00まで)\n"
        printf "⏰ リセット予定: UTC 17:00 (JST 02:00)\n"
    fi
    
    printf "==============================\n"
    printf "💡 終了するには Ctrl+C を押してください\n\n"
}

# リアルタイム監視モード
monitor_mode() {
    echo "🚀 Claude使用量リアルタイム監視を開始します..."
    echo "終了するには Ctrl+C を押してください"
    echo ""
    
    while true; do
        clear
        local current_usage=$(get_latest_usage)
        display_usage_status "$current_usage"
        
        # 現在のアクティブ役割も表示
        if [ -f "$SHARED_DIR/active_role.txt" ]; then
            local active_role=$(cat "$SHARED_DIR/active_role.txt" 2>/dev/null | head -1)
            if [ -n "$active_role" ]; then
                printf "🎯 現在アクティブ: %s\n" "$active_role"
            fi
        fi
        
        if [ -f "$SHARED_DIR/progress.txt" ]; then
            local progress=$(cat "$SHARED_DIR/progress.txt" 2>/dev/null | head -1)
            if [ -n "$progress" ]; then
                printf "📝 進捗状況: %s\n" "$progress"
            fi
        fi
        
        sleep 30  # 30秒間隔で更新
    done
}

# ワンショット表示モード
oneshot_mode() {
    local current_usage=$(get_latest_usage)
    display_usage_status "$current_usage"
}

# メイン処理
main() {
    case "${1:-oneshot}" in
        "monitor"|"watch"|"-m")
            monitor_mode
            ;;
        "oneshot"|"show"|"-s"|"")
            oneshot_mode
            ;;
        "help"|"-h"|"--help")
            echo "使用方法:"
            echo "  $0                リアルタイム使用量を1回表示"
            echo "  $0 monitor        リアルタイム監視モード"
            echo "  $0 oneshot        使用量を1回表示"
            echo "  $0 help           このヘルプを表示"
            ;;
        *)
            echo "不明なオプション: $1"
            echo "ヘルプを表示するには: $0 help"
            exit 1
            ;;
    esac
}

# Ctrl+Cのハンドリング
trap 'echo ""; echo "監視を終了します..."; exit 0' INT

# スクリプトが直接実行された場合
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi