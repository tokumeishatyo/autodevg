#!/bin/bash
# Claude使用量表示モニター（max5プラン対応版）
# 進捗モニターと統一されたシンプルな表示

USAGE_LOG="/tmp/autodevg_status/claude_usage.log"
SHARED_DIR="/tmp/autodevg_status"
START_TIME_FILE="$SHARED_DIR/session_start_time.txt"
BASELINE_FILE="$SHARED_DIR/project_baseline.txt"
WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# max5プラン設定
MAX_TOKENS=200000
MAX_PROMPTS=400
RESET_INTERVAL_HOURS=5

# 共有ディレクトリが存在しない場合は作成
mkdir -p "$SHARED_DIR"

# セッション開始からの経過時間を取得（秒）
get_elapsed_seconds() {
    if [ -f "$START_TIME_FILE" ]; then
        local start_time=$(cat "$START_TIME_FILE")
        local current_time=$(date +%s)
        echo $((current_time - start_time))
    else
        echo "0"
    fi
}

# リセットまでの残り時間を取得（秒）
get_remaining_seconds() {
    local elapsed=$(get_elapsed_seconds)
    local reset_seconds=$((RESET_INTERVAL_HOURS * 3600))
    local remaining=$((reset_seconds - (elapsed % reset_seconds)))
    echo $remaining
}

# リセットまでの残り時間を人間可読形式で取得
get_remaining_time_string() {
    local remaining=$(get_remaining_seconds)
    local hours=$((remaining / 3600))
    local minutes=$(((remaining % 3600) / 60))
    echo "${hours}時間${minutes}分"
}

# 最新の使用量データを取得
get_latest_usage_data() {
    if [ -f "$USAGE_LOG" ]; then
        local latest_line=$(tail -1 "$USAGE_LOG")
        echo "$latest_line"
    else
        echo ""
    fi
}

# 使用量情報を解析
parse_usage_data() {
    local data="$1"
    
    # トークン使用量
    local tokens=$(echo "$data" | grep -oE 'トークン: [0-9]+' | grep -oE '[0-9]+' | head -1 || echo "0")
    local token_percentage=$(echo "$data" | sed -n 's/.*トークン:[^(]*(\([0-9]\+\)%).*/\1/p' | head -1 || echo "0")
    
    # プロンプト使用量
    local prompts=$(echo "$data" | grep -oE 'プロンプト: [0-9]+' | grep -oE '[0-9]+' | head -1 || echo "0")
    local prompt_percentage=$(echo "$data" | sed -n 's/.*プロンプト:[^(]*(\([0-9]\+\)%).*/\1/p' | head -1 || echo "0")
    
    # データソース
    local source=$(echo "$data" | grep -oE 'source: [a-z-]+' | cut -d' ' -f2 || echo "unknown")
    
    echo "$tokens|$token_percentage|$prompts|$prompt_percentage|$source"
}

# カウンター
counter=0

# 画面クリア関数
clear_screen() {
    clear
    echo "================================================================"
    echo "            📊 Claude使用量モニター (max5プラン)"
    echo "================================================================"
    echo ""
}

# プロジェクトベースラインを読み込み
load_project_baseline() {
    if [ -f "$BASELINE_FILE" ]; then
        source "$BASELINE_FILE"
    else
        PROJECT_START_TOKENS=0
        PROJECT_START_TIME="N/A"
        PROJECT_NAME="Unknown"
    fi
}

# プロジェクト使用量計算
calculate_project_usage() {
    local current_tokens="$1"
    local baseline_tokens="${PROJECT_START_TOKENS:-0}"
    
    if [ "$baseline_tokens" -eq 0 ] || [ "$current_tokens" -lt "$baseline_tokens" ]; then
        echo "0"
    else
        echo $((current_tokens - baseline_tokens))
    fi
}

# 使用量状況の表示
display_usage_status() {
    # プロジェクトベースラインを読み込み
    load_project_baseline
    
    local usage_data=$(get_latest_usage_data)
    
    if [ -z "$usage_data" ]; then
        echo "⚠️  使用量: データなし"
        echo "💡 状態: 初回チェック待ち"
    else
        # データ解析
        IFS='|' read -r tokens token_pct prompts prompt_pct source <<< "$(parse_usage_data "$usage_data")"
        
        # プロジェクト使用量計算
        local project_tokens=$(calculate_project_usage "$tokens")
        
        # 状態判定
        local max_pct=$token_pct
        if [ "$prompt_pct" -gt "$max_pct" ]; then
            max_pct=$prompt_pct
        fi
        
        local status_icon=""
        local status_text=""
        if [ "$max_pct" -lt 50 ]; then
            status_icon="✅"
            status_text="正常動作中"
        elif [ "$max_pct" -lt 75 ]; then
            status_icon="⚠️"
            status_text="使用量やや高め"
        elif [ "$max_pct" -lt 85 ]; then
            status_icon="🚨"
            status_text="間もなく制限に到達"
        else
            status_icon="🚫"
            status_text="待機モード推奨"
        fi
        
        # プログレスドット
        local dots=""
        case $((counter % 4)) in
            0) dots="●○○○" ;;
            1) dots="○●○○" ;;
            2) dots="○○●○" ;;
            3) dots="○○○●" ;;
        esac
        
        # リセット情報
        local remaining_time=$(get_remaining_time_string)
        
        # 表示
        echo "📊 使用量状況"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "🌐 本日累計: $tokens / $MAX_TOKENS ($token_pct%)"
        echo "📁 プロジェクト: ${project_tokens}トークン（開始: ${PROJECT_START_TOKENS}）"
        if [ "$project_tokens" -gt 0 ]; then
            local cost_estimate=$(echo "scale=2; $project_tokens * 0.000015" | bc 2>/dev/null || echo "N/A")
            echo "💰 推定コスト: \$$cost_estimate"
        fi
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "💬 プロンプト使用量: $prompts / $MAX_PROMPTS ($prompt_pct%)"
        echo "⏰ リセットまで: $remaining_time $dots | 📅 $(TZ=Asia/Tokyo date '+%H:%M JST')"
        echo "📡 データソース: $source"
        echo "🔄 更新回数: $counter"
        echo ""
        echo "$status_icon 状態: $status_text"
    fi
    
    # 現在のアクティブ役割も表示
    if [ -f "$SHARED_DIR/active_role.txt" ]; then
        local active_role=$(cat "$SHARED_DIR/active_role.txt" 2>/dev/null | head -1)
        if [ -n "$active_role" ]; then
            echo "🎯 現在アクティブ: $active_role"
        fi
    fi
    
    if [ -f "$SHARED_DIR/progress.txt" ]; then
        local progress=$(cat "$SHARED_DIR/progress.txt" 2>/dev/null | head -1)
        if [ -n "$progress" ]; then
            echo "📝 進捗状況: $progress"
        fi
    fi
    
    echo ""
    echo "💡 このモニターは独立して動作します"
    echo "💡 終了するには Ctrl+C を押してください"
    echo ""
    echo "================================================================"
}

# リアルタイム監視モード
monitor_mode() {
    echo "🚀 Claude使用量モニターを起動しています..."
    sleep 2
    
    while true; do
        clear_screen
        display_usage_status
        counter=$((counter + 1))
        sleep 30  # 30秒間隔で更新
    done
}

# ワンショット表示モード
oneshot_mode() {
    display_usage_status
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
cleanup() {
    echo ""
    echo "🛑 使用量モニターを終了しています..."
    exit 0
}

trap cleanup SIGINT SIGTERM

# スクリプトが直接実行された場合
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi