#!/bin/bash
# Manager専用待機モード管理スクリプト

STANDBY_DIR="/workspace/Demo/tmp/standby"
WORK_STATE_FILE="$STANDBY_DIR/work_state.txt"
STANDBY_LOG="$STANDBY_DIR/standby_log.txt"

# 共有ディレクトリを作成
mkdir -p "$STANDBY_DIR"

# 現在時刻（日本時間）
JST_TIME=$(TZ=Asia/Tokyo date '+%Y-%m-%d %H:%M:%S JST')

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

# 待機モードに入る
enter_standby_mode() {
    local reason="$1"
    local current_work="$2"
    local next_action="$3"
    
    local recovery_time=$(calculate_recovery_time)
    
    # 作業状態を記録
    cat > "$WORK_STATE_FILE" << EOF
# Manager作業状態記録
# 待機開始時刻: $JST_TIME
# 待機理由: $reason
# 復帰可能時間: $recovery_time

## 中断時の作業状況
現在の作業: $current_work

## 復帰時の次のアクション
次の作業: $next_action

## 待機前の状況メモ
- 最後に受信したメッセージを確認してください
- 各役割の進捗状況を確認してください
- 必要に応じて追加の指示を準備してください

## 復帰手順
1. /restart コマンドを入力
2. 上記の作業状況を確認
3. 次のアクションを実行
EOF

    # 待機ログに記録
    echo "[$JST_TIME] 待機モード開始: $reason" >> "$STANDBY_LOG"
    
    # 進捗モニターに状態更新
    /workspace/Demo/scripts/update_progress_status.sh "Manager" "⏸️ 待機モード: Claude使用量制限" "待機" >/dev/null 2>&1
    
    # Managerペインにフォーカス
    tmux select-pane -t claude_workspace:0.1
    
    # 待機モード表示
    echo "🚫 ===== Manager待機モード ====="
    echo "📅 開始時刻: $JST_TIME"
    echo "⚠️ 理由: $reason"
    echo "⏰ 復帰可能時間: $recovery_time"
    echo "🎯 中断作業: $current_work"
    echo "▶️ 次のアクション: $next_action"
    echo ""
    echo "💡 復帰方法: /restart コマンドを入力してください"
    echo "📁 作業状態: $WORK_STATE_FILE に保存済み"
    echo "================================"
    
    return 0
}

# 待機モードから復帰
exit_standby_mode() {
    if [ ! -f "$WORK_STATE_FILE" ]; then
        echo "❌ 作業状態ファイルが見つかりません。"
        return 1
    fi
    
    echo "🔄 ===== Manager作業再開 ====="
    echo "📅 復帰時刻: $JST_TIME"
    echo ""
    echo "📋 前回の作業状況:"
    cat "$WORK_STATE_FILE"
    echo ""
    echo "✅ 作業を再開してください。"
    echo "================================"
    
    # 復帰ログに記録
    echo "[$JST_TIME] 待機モード終了: 作業再開" >> "$STANDBY_LOG"
    
    # 進捗モニターに状態更新
    /workspace/Demo/scripts/update_progress_status.sh "Manager" "🔄 待機モードから復帰、作業再開中..." "復帰" >/dev/null 2>&1
    
    return 0
}

# 他の役割からの制限報告を受信
receive_limit_report() {
    local reporting_role="$1"
    local message="$2"
    
    echo "⚠️ [$reporting_role] から使用量制限の報告を受信しました:"
    echo "$message"
    echo ""
    
    # 現在の状況を記録して待機モードに入る
    enter_standby_mode "他役割からの使用量制限報告" "[$reporting_role]からの報告対応" "使用量回復後に[$reporting_role]への次の指示を検討"
}

# メイン処理
main() {
    case "${1:-help}" in
        "enter")
            enter_standby_mode "$2" "$3" "$4"
            ;;
        "exit"|"restart")
            exit_standby_mode
            ;;
        "report")
            receive_limit_report "$2" "$3"
            ;;
        "status")
            if [ -f "$WORK_STATE_FILE" ]; then
                echo "📋 現在の作業状態:"
                cat "$WORK_STATE_FILE"
            else
                echo "ℹ️ 待機モードではありません。"
            fi
            ;;
        "help"|*)
            echo "使用方法:"
            echo "  $0 enter [理由] [現在作業] [次アクション]  # 待機モード開始"
            echo "  $0 exit                                   # 待機モード終了"
            echo "  $0 restart                               # 待機モード終了"
            echo "  $0 report [役割] [メッセージ]             # 他役割からの制限報告"
            echo "  $0 status                                # 現在の状態確認"
            ;;
    esac
}

# スクリプトが直接実行された場合
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi