#!/bin/bash
# ManagerペインからCEOペインにメッセージを送信するスクリプト（ファイルベース版）

# メッセージを引数から取得
MESSAGE="$*"

if [ -z "$MESSAGE" ]; then
    echo "使用方法: ./scripts/manager_to_ceo.sh メッセージ内容"
    echo "例: ./scripts/manager_to_ceo.sh 要件定義書の初期版を作成しました。レビューをお願いします。"
    exit 1
fi

# 現在のペインを保存
CURRENT_PANE=$(tmux display-message -p '#P')

# Manager作業完了のため進捗表示を停止
/workspace/Demo/scripts/stop_progress.sh >/dev/null 2>&1

# 作業種別を自動検出
WORK_TYPE=$(source /workspace/Demo/scripts/detect_work_type.sh && detect_work_type "$MESSAGE" 1 0)

# メッセージをファイルに書き込み（上書き）
echo "$MESSAGE" > /workspace/Demo/tmp/tmp_manager.txt

# ログファイルに追記
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Manager → CEO: $MESSAGE" >> /workspace/Demo/logs/communication_log.txt

# 独立ターミナルの進捗モニターに状態更新
/workspace/Demo/scripts/update_progress_status.sh "CEO" "Managerからの報告を受信、検討中..." "$WORK_TYPE" >/dev/null 2>&1

# CEOペインで進捗表示を開始
/workspace/Demo/scripts/start_progress.sh 0 "$WORK_TYPE" >/dev/null 2>&1 &

# CEOペイン（pane 0）に切り替えて通知メッセージを送信
tmux select-pane -t claude_workspace:0.0
tmux send-keys -t claude_workspace:0.0 "cat /workspace/Demo/tmp/tmp_manager.txt"
tmux send-keys -t claude_workspace:0.0 C-m

# 元のペインに戻る
tmux select-pane -t claude_workspace:0.$CURRENT_PANE

echo "[Manager → CEO] メッセージをtmp/tmp_manager.txtに書き込みました (進捗表示: Manager停止 → CEO開始: $WORK_TYPE)"