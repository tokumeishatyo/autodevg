#!/bin/bash
# Claude使用量モニターのセットアップスクリプト

echo "🔍 Claude使用量モニターをセットアップしています..."

# uvがインストールされているかチェック
if ! command -v uv >/dev/null 2>&1; then
    echo "📦 uvをインストールしています..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    
    # パスを再読み込み
    export PATH="$HOME/.cargo/bin:$PATH"
    source ~/.bashrc 2>/dev/null || true
fi

# claude-monitorがインストールされているかチェック
if ! command -v claude-monitor >/dev/null 2>&1; then
    echo "📊 claude-monitorをインストールしています..."
    uv tool install claude-monitor
fi

# エイリアスを作成
echo "⚙️ 便利なエイリアスを設定しています..."

cat >> ~/.bashrc << 'EOF'

# AutoDev Claude Monitor Aliases
alias claude-usage='claude-monitor --timezone Asia/Tokyo --plan Pro'
alias claude-usage-max='claude-monitor --timezone Asia/Tokyo --plan Max5'
alias autodev-monitor='claude-monitor --timezone Asia/Tokyo --plan Pro'
EOF

echo "✅ Claude使用量モニターのセットアップが完了しました！"
echo ""
echo "🚀 使用方法:"
echo "  claude-usage        # 基本的な使用量確認"
echo "  claude-usage-max    # Max5プラン用"
echo "  autodev-monitor     # autodev専用エイリアス"
echo ""
echo "💡 新しいターミナルを開くか、以下を実行してエイリアスを有効化:"
echo "  source ~/.bashrc"