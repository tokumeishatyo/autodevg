#!/bin/bash
# ManagerペインからDeveloperペインにメッセージを送信するスクリプト（ファイルベース版）

# 日本時間で現在時刻を取得
current_time() {
    TZ=Asia/Tokyo date '+%Y-%m-%d %H:%M:%S'
}

# メッセージを引数から取得
MESSAGE="$*"

if [ -z "$MESSAGE" ]; then
    echo "使用方法: ./scripts/manager_to_developer.sh メッセージ内容"
    echo "例: ./scripts/manager_to_developer.sh 詳細仕様書の作成を開始してください。"
    exit 1
fi

# 現在のペインを保存
CURRENT_PANE=$(tmux display-message -p '#P')

# 作業種別を自動検出
WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_TYPE=$(source "$WORKSPACE_DIR/scripts/detect_work_type.sh" && detect_work_type "$MESSAGE" 0 1)

# tmuxセッション生存確認
echo "🔍 tmuxセッション生存確認を実行しています..."
if ! tmux has-session -t autodevg_workspace 2>/dev/null; then
    echo "❌ tmuxセッションが見つかりません。システムを復旧します..."
    if [ -f "$WORKSPACE_DIR/scripts/health_check.sh" ]; then
        "$WORKSPACE_DIR/scripts/health_check.sh" recover
        if [ $? -ne 0 ]; then
            echo "❌ システム復旧に失敗しました。手動でシステムを再起動してください。"
            exit 1
        fi
    else
        echo "❌ health_check.shが見つかりません。手動でシステムを再起動してください。"
        exit 1
    fi
fi

# Developerペイン（pane 1）の生存確認
if ! tmux list-panes -t autodevg_workspace | grep -q "^1:"; then
    echo "❌ Developerペインが見つかりません。システムを復旧します..."
    if [ -f "$WORKSPACE_DIR/scripts/health_check.sh" ]; then
        "$WORKSPACE_DIR/scripts/health_check.sh" recover
        if [ $? -ne 0 ]; then
            echo "❌ システム復旧に失敗しました。手動でシステムを再起動してください。"
            exit 1
        fi
    fi
fi

# 通信前チェック（リミット＋生存確認）
HEALTH_INTEGRATION="$WORKSPACE_DIR/scripts/manager_health_integration.sh"
if [ -f "$HEALTH_INTEGRATION" ]; then
    echo "📊 システム状態とClaude使用量をチェックしています..."
    "$HEALTH_INTEGRATION" comm_check "Developer" "$MESSAGE"
    local check_result=$?
    
    if [ $check_result -eq 2 ]; then
        echo "待機モードに移行したため通信を中止しました"
        exit 2
    elif [ $check_result -eq 1 ]; then
        echo "システム異常のため通信を中止しました"
        exit 1
    fi
else
    # 従来のチェック方法（フォールバック）
    echo "📊 Claude使用量をチェックしています..."
    if ! "$WORKSPACE_DIR/scripts/check_claude_usage.sh"; then
        echo "❌ 使用量チェックでエラーが発生しました。"
        exit 1
    fi
fi

# メッセージをファイルに書き込み（上書き）
echo "$MESSAGE" > "$WORKSPACE_DIR/tmp/tmp_manager.txt"

# ログファイルに追記（日本時間）
echo "[$(TZ=Asia/Tokyo date '+%Y-%m-%d %H:%M:%S')] Manager → Developer: $MESSAGE" >> "$WORKSPACE_DIR/logs/communication_log.txt"

# 独立ターミナルの進捗モニターに状態更新
"$WORKSPACE_DIR/scripts/update_progress_status.sh" "Developer" "Managerからの指示を受信、開発作業を開始..." "$WORK_TYPE" >/dev/null 2>&1

# Developerペイン（pane 1）に切り替えて通知メッセージを送信
echo "📤 Developerペインにメッセージを送信しています..."
tmux select-pane -t autodevg_workspace:0.1
tmux send-keys -t autodevg_workspace:0.1 "cat \"$WORKSPACE_DIR/tmp/tmp_manager.txt\""
tmux send-keys -t autodevg_workspace:0.1 C-m

# 送信確認のため少し待機
sleep 2

# Developerペインが応答可能かを確認
echo "🔍 Developerペインの応答確認を実行しています..."
tmux send-keys -t autodevg_workspace:0.1 "echo \"[$(current_time)] Manager → Developer メッセージ受信確認\""
tmux send-keys -t autodevg_workspace:0.1 C-m

# 元のペインに戻る
tmux select-pane -t autodevg_workspace:0.$CURRENT_PANE

echo "✅ [Manager → Developer] メッセージをtmp/tmp_manager.txtに書き込み、Developerペインに送信しました (進捗表示開始: $WORK_TYPE)"
echo "📋 メッセージ内容: $(echo "$MESSAGE" | head -c 60)..."