#!/bin/bash
# CEOペインからManagerペインにメッセージを送信するスクリプト（ファイルベース版）

# メッセージを引数から取得
MESSAGE="$*"

if [ -z "$MESSAGE" ]; then
    echo "使用方法: ./scripts/ceo_to_manager.sh メッセージ内容"
    echo "例: ./scripts/ceo_to_manager.sh planning.txtを確認しました。要件定義書の作成を開始してください。"
    exit 1
fi

# 現在のペインを保存
CURRENT_PANE=$(tmux display-message -p '#P')

# 作業種別を自動検出
WORK_TYPE=$(source /workspace/Demo/scripts/detect_work_type.sh && detect_work_type "$MESSAGE" 0 1)

# Claude使用量をチェック
echo "📊 Claude使用量をチェックしています..."
if ! /workspace/Demo/scripts/check_claude_usage.sh; then
    echo "❌ 使用量チェックでエラーが発生しました。"
    exit 1
fi

# メッセージをファイルに書き込み（上書き）
echo "$MESSAGE" > /workspace/Demo/tmp/tmp_ceo.txt

# ログファイルに追記
echo "[$(date '+%Y-%m-%d %H:%M:%S')] CEO → Manager: $MESSAGE" >> /workspace/Demo/logs/communication_log.txt

# 独立ターミナルの進捗モニターに状態更新
/workspace/Demo/scripts/update_progress_status.sh "Manager" "CEOからの指示を受信、作業を開始しています..." "$WORK_TYPE" >/dev/null 2>&1

# Managerペイン（pane 1）に切り替えて通知メッセージを送信
tmux select-pane -t claude_workspace:0.1
tmux send-keys -t claude_workspace:0.1 "cat /workspace/Demo/tmp/tmp_ceo.txt"
tmux send-keys -t claude_workspace:0.1 C-m

# 元のペインに戻る
tmux select-pane -t claude_workspace:0.$CURRENT_PANE

echo "[CEO → Manager] メッセージをtmp/tmp_ceo.txtに書き込みました (進捗表示開始: $WORK_TYPE)"