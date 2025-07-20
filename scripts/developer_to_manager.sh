#!/bin/bash
# DeveloperペインからManagerペインにメッセージを送信するスクリプト（ファイルベース版）

# 日本時間で現在時刻を取得
current_time() {
    TZ=Asia/Tokyo date '+%Y-%m-%d %H:%M:%S'
}

# メッセージを引数から取得
MESSAGE="$*"

if [ -z "$MESSAGE" ]; then
    echo "使用方法: ./scripts/developer_to_manager.sh メッセージ内容"
    echo "例: ./scripts/developer_to_manager.sh 詳細仕様書を作成しました。レビューをお願いします。"
    exit 1
fi

# 現在のペインを保存
CURRENT_PANE=$(tmux display-message -p '#P')

# ベースディレクトリを取得
WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Developer作業完了のため進捗表示を停止
"$WORKSPACE_DIR/scripts/stop_progress.sh" >/dev/null 2>&1

# 作業種別を自動検出
WORK_TYPE=$(source "$WORKSPACE_DIR/scripts/detect_work_type.sh" && detect_work_type "$MESSAGE" 1 0)

# メッセージをファイルに書き込み（上書き）
echo "$MESSAGE" > "$WORKSPACE_DIR/tmp/tmp_developer.txt"

# ログファイルに追記
echo "[$(TZ=Asia/Tokyo date '+%Y-%m-%d %H:%M:%S')] Developer → Manager: $MESSAGE" >> "$WORKSPACE_DIR/logs/communication_log.txt"

# 独立ターミナルの進捗モニターに状態更新
"$WORKSPACE_DIR/scripts/update_progress_status.sh" "Manager" "Developerからの報告を受信、確認中..." "$WORK_TYPE" >/dev/null 2>&1

# tmuxセッション生存確認
echo "🔍 tmuxセッション生存確認を実行しています..."
if ! tmux has-session -t autodevg_workspace 2>/dev/null; then
    echo "❌ tmuxセッションが見つかりません。通信できません。"
    echo "手動でシステムを再起動してください。"
    exit 1
fi

# Managerペイン（pane 0）の生存確認
if ! tmux list-panes -t autodevg_workspace | grep -q "^0:"; then
    echo "❌ Managerペインが見つかりません。通信できません。"
    exit 1
fi

# Managerペイン（pane 0）に切り替えて通知メッセージを送信
echo "📤 Managerペインにメッセージを送信しています..."
tmux select-pane -t autodevg_workspace:0.0
tmux send-keys -t autodevg_workspace:0.0 "cat \"$WORKSPACE_DIR/tmp/tmp_developer.txt\""
tmux send-keys -t autodevg_workspace:0.0 C-m

# 送信確認のため少し待機
sleep 2

# Managerペインが応答可能かを確認
echo "🔍 Managerペインの応答確認を実行しています..."
tmux send-keys -t autodevg_workspace:0.0 "echo \"[$(current_time)] Developer → Manager メッセージ受信確認\""
tmux send-keys -t autodevg_workspace:0.0 C-m

# 元のペインに戻る
tmux select-pane -t autodevg_workspace:0.$CURRENT_PANE

echo "✅ [Developer → Manager] メッセージをtmp/tmp_developer.txtに書き込み、Managerペインに送信しました (進捗表示: Developer停止 → Manager開始: $WORK_TYPE)"
echo "📋 メッセージ内容: $(echo "$MESSAGE" | head -c 60)..."