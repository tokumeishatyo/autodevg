#!/bin/bash
# ターミナル間通信用状態更新スクリプト

# 使用方法チェック
if [ $# -lt 2 ]; then
    echo "使用方法: $0 <role> <message> [work_type]"
    echo "role: CEO, Manager, Reviewer, Developer"
    echo "message: 進捗メッセージ"
    echo "work_type: thinking, document_creation, code_development, etc."
    exit 1
fi

ROLE="$1"
MESSAGE="$2"
WORK_TYPE="${3:-thinking}"

# 共有ディレクトリ設定
SHARED_DIR="/tmp/autodev_status"
ACTIVE_ROLE_FILE="$SHARED_DIR/active_role.txt"
PROGRESS_FILE="$SHARED_DIR/progress.txt" 
WORK_TYPE_FILE="$SHARED_DIR/work_type.txt"
START_TIME_FILE="$SHARED_DIR/start_time.txt"

# 共有ディレクトリを作成
mkdir -p "$SHARED_DIR"

# 状態を更新
echo "$ROLE" > "$ACTIVE_ROLE_FILE"
echo "$MESSAGE" > "$PROGRESS_FILE"
echo "$WORK_TYPE" > "$WORK_TYPE_FILE"
echo $(date +%s) > "$START_TIME_FILE"

echo "✅ 進捗状態を更新しました: $ROLE - $MESSAGE ($WORK_TYPE)"