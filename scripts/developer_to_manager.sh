#!/bin/bash
# DeveloperペインからManagerペインにメッセージを送信するスクリプト（ファイルベース版）

# メッセージを引数から取得
MESSAGE="$*"

if [ -z "$MESSAGE" ]; then
    echo "使用方法: ./scripts/developer_to_manager.sh メッセージ内容"
    echo "例: ./scripts/developer_to_manager.sh 詳細仕様書を作成しました。レビューをお願いします。"
    exit 1
fi

# 現在のペインを保存
CURRENT_PANE=$(tmux display-message -p '#P')

# Developer作業完了のため進捗表示を停止
/workspace/Demo/scripts/stop_progress.sh >/dev/null 2>&1

# 作業種別を自動検出
WORK_TYPE=$(source /workspace/Demo/scripts/detect_work_type.sh && detect_work_type "$MESSAGE" 4 1)

# メッセージをファイルに書き込み（上書き）
echo "$MESSAGE" > /workspace/Demo/tmp/tmp_developer.txt

# ログファイルに追記
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Developer → Manager: $MESSAGE" >> /workspace/Demo/logs/communication_log.txt

# 独立ターミナルの進捗モニターに状態更新
/workspace/Demo/scripts/update_progress_status.sh "Manager" "Developerからの報告を受信、確認中..." "$WORK_TYPE" >/dev/null 2>&1

# Managerペイン（pane 1）に切り替えて通知メッセージを送信
tmux select-pane -t claude_workspace:0.1
tmux send-keys -t claude_workspace:0.1 "cat /workspace/Demo/tmp/tmp_developer.txt"
tmux send-keys -t claude_workspace:0.1 C-m

# 元のペインに戻る
tmux select-pane -t claude_workspace:0.$CURRENT_PANE

echo "[Developer → Manager] メッセージをtmp/tmp_developer.txtに書き込みました (進捗表示: Developer停止 → Manager開始: $WORK_TYPE)"