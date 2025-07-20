#!/bin/bash
# 通信状況確認スクリプト

# 設定
WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_FILE="$WORKSPACE_DIR/logs/communication_log.txt"
MANAGER_FILE="$WORKSPACE_DIR/tmp/tmp_manager.txt"
DEVELOPER_FILE="$WORKSPACE_DIR/tmp/tmp_developer.txt"

# 日本時間で現在時刻を取得
current_time() {
    TZ=Asia/Tokyo date '+%Y-%m-%d %H:%M:%S'
}

# 通信状況を確認
echo "=== 通信状況確認 $(current_time) ==="

# tmuxセッション確認
echo "🔍 tmuxセッション確認:"
if tmux has-session -t autodevg_workspace 2>/dev/null; then
    echo "✅ autodevg_workspace セッション: 生存中"
    
    # ペイン情報を取得
    echo "📋 ペイン情報:"
    tmux list-panes -t autodevg_workspace -F "#{pane_index}: #{pane_title} (#{pane_width}x#{pane_height})"
else
    echo "❌ autodevg_workspace セッション: 見つかりません"
fi

echo ""

# ファイル確認
echo "📁 通信ファイル確認:"

if [ -f "$MANAGER_FILE" ]; then
    echo "✅ Manager → Developer ファイル: 存在"
    echo "   最終更新: $(stat -c %y "$MANAGER_FILE" 2>/dev/null || echo '不明')"
    echo "   サイズ: $(wc -c < "$MANAGER_FILE" 2>/dev/null || echo '0') bytes"
    echo "   内容プレビュー: $(head -c 100 "$MANAGER_FILE" 2>/dev/null | tr '\n' ' ' || echo '読み取り不可')..."
else
    echo "❌ Manager → Developer ファイル: 存在しません ($MANAGER_FILE)"
fi

echo ""

if [ -f "$DEVELOPER_FILE" ]; then
    echo "✅ Developer → Manager ファイル: 存在"
    echo "   最終更新: $(stat -c %y "$DEVELOPER_FILE" 2>/dev/null || echo '不明')"
    echo "   サイズ: $(wc -c < "$DEVELOPER_FILE" 2>/dev/null || echo '0') bytes"
    echo "   内容プレビュー: $(head -c 100 "$DEVELOPER_FILE" 2>/dev/null | tr '\n' ' ' || echo '読み取り不可')..."
else
    echo "❌ Developer → Manager ファイル: 存在しません ($DEVELOPER_FILE)"
fi

echo ""

# 通信ログ確認
echo "📜 通信ログ確認:"
if [ -f "$LOG_FILE" ]; then
    echo "✅ 通信ログファイル: 存在"
    echo "   最終更新: $(stat -c %y "$LOG_FILE" 2>/dev/null || echo '不明')"
    echo "   行数: $(wc -l < "$LOG_FILE" 2>/dev/null || echo '0')"
    echo "   最新5件:"
    tail -5 "$LOG_FILE" 2>/dev/null | sed 's/^/   /' || echo "   読み取り不可"
else
    echo "❌ 通信ログファイル: 存在しません ($LOG_FILE)"
fi

echo ""
echo "=== 確認完了 ==="