#!/bin/bash
# 独立ターミナルで進捗モニターを起動するスクリプト

echo "🚀 AutoDev 進捗モニターを新しいターミナルで起動しています..."

# 使用可能なターミナルエミュレータを検出して起動
if command -v gnome-terminal >/dev/null 2>&1; then
    gnome-terminal -- bash -c "/workspace/Demo/scripts/progress_monitor.sh; exec bash"
elif command -v xterm >/dev/null 2>&1; then
    xterm -e "/workspace/Demo/scripts/progress_monitor.sh; exec bash" &
elif command -v konsole >/dev/null 2>&1; then
    konsole -e "/workspace/Demo/scripts/progress_monitor.sh; exec bash" &
elif command -v alacritty >/dev/null 2>&1; then
    alacritty -e bash -c "/workspace/Demo/scripts/progress_monitor.sh; exec bash" &
else
    echo "⚠️ GUIターミナルエミュレータが見つかりません。"
    echo "🔄 バックグラウンドモードで進捗監視を開始します..."
    
    # バックグラウンドで進捗監視を開始
    nohup /workspace/Demo/scripts/progress_monitor.sh > /tmp/autodev_status/progress_monitor.log 2>&1 &
    echo $! > /tmp/autodev_status/progress_monitor.pid
    
    echo "✅ 進捗監視がバックグラウンドで開始されました！"
    echo "📊 監視状況を確認するには以下のコマンドを実行："
    echo "    tail -f /tmp/autodev_status/progress_monitor.log"
    echo "    ./scripts/usage_monitor_display.sh"
    echo ""
    return 0
fi

echo "✅ 進捗モニターが別ターミナルで起動されました！"
echo "💡 メインのtmuxセッションとは独立して動作します。"