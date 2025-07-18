#!/bin/bash
# /goコマンドハンドラースクリプト

# 共有ディレクトリ設定
SHARED_DIR="/tmp/autodevg_status"
mkdir -p "$SHARED_DIR"

# 進捗状況の更新
echo "Manager" > "$SHARED_DIR/active_role.txt"
echo "開発プロセス開始中..." > "$SHARED_DIR/progress.txt"
echo "planning" > "$SHARED_DIR/work_type.txt"
echo $(date +%s) > "$SHARED_DIR/start_time.txt"

echo "🚀 /goコマンドが実行されました"
echo "📋 planning.txtを読み込んで開発プロセスを開始します"
echo "⏰ 開始時刻: $(date '+%Y-%m-%d %H:%M:%S')"