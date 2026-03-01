#!/bin/bash
# 快速创建研究项目模板
# 用法：./create-research-project.sh {{项目名称}}

set -e

PROJECT_NAME="$1"
TEMPLATES_DIR="/Users/eddy/.openclaw/workspace/ai-knowledge-base/templates/research-project"
PLANNING_DIR="/Users/eddy/.openclaw/workspace/ai-knowledge-base/.planning"
RESEARCH_DIR="/Users/eddy/.openclaw/workspace/ai-knowledge-base/research-reports"

if [ -z "$PROJECT_NAME" ]; then
    echo "❌ 用法：$0 {{项目名称}}"
    echo "示例：$0 MarkItDown"
    exit 1
fi

echo "=========================================="
echo "🚀 创建研究项目：$PROJECT_NAME"
echo "=========================================="
echo ""

# 创建目录
echo "📁 创建项目目录..."
mkdir -p "$PLANNING_DIR/$PROJECT_NAME"
mkdir -p "$RESEARCH_DIR/$PROJECT_NAME"
echo "   ✅ $PLANNING_DIR/$PROJECT_NAME"
echo "   ✅ $RESEARCH_DIR/$PROJECT_NAME"
echo ""

# 复制模板
echo "📋 复制模板文件..."
cp "$TEMPLATES_DIR/PROJECT.md" "$PLANNING_DIR/$PROJECT_NAME/"
cp "$TEMPLATES_DIR/REQUIREMENTS.md" "$PLANNING_DIR/$PROJECT_NAME/"
cp "$TEMPLATES_DIR/ROADMAP.md" "$PLANNING_DIR/$PROJECT_NAME/"
cp "$TEMPLATES_DIR/STATE.md" "$PLANNING_DIR/$PROJECT_NAME/"
# 注意：不复制 research-report-template.md 为 01-overview.md
# 避免模板文件残留，实际研究报告由研究者创建
echo "   ✅ PROJECT.md"
echo "   ✅ REQUIREMENTS.md"
echo "   ✅ ROADMAP.md"
echo "   ✅ STATE.md"
echo ""

# 替换占位符
echo "🔧 替换占位符..."
DATE=$(date +%Y-%m-%d)
for file in "$PLANNING_DIR/$PROJECT_NAME"/*.md "$RESEARCH_DIR/$PROJECT_NAME/01-overview.md"; do
    sed -i.bak "s/{{项目名称}}/$PROJECT_NAME/g" "$file"
    sed -i.bak "s/{{日期}}/$DATE/g" "$file"
    sed -i.bak "s/{{研究者}}/$(whoami)/g" "$file"
    rm -f "$file.bak"
done
echo "   ✅ 占位符已替换为：$PROJECT_NAME"
echo "   ✅ 日期已设置为：$DATE"
echo ""

# Git 提交
echo "📝 Git 提交..."
cd /Users/eddy/.openclaw/workspace/ai-knowledge-base
git add ".planning/$PROJECT_NAME/" "research-reports/$PROJECT_NAME/"
git commit -m "Create $PROJECT_NAME research project

- Add project planning templates (PROJECT, REQUIREMENTS, ROADMAP, STATE)
- Add initial research report template (01-overview.md)
- Ready to start Phase 1" || echo "⚠️  无变更或 Git 未配置"
echo "   ✅ 已提交"
echo ""

echo "=========================================="
echo "✅ 项目创建完成！"
echo "=========================================="
echo ""
echo "📁 项目位置:"
echo "   规划文档：$PLANNING_DIR/$PROJECT_NAME/"
echo "   研究报告：$RESEARCH_DIR/$PROJECT_NAME/"
echo ""
echo "📝 下一步:"
echo "   1. 编辑 .planning/$PROJECT_NAME/PROJECT.md"
echo "   2. 编辑 .planning/$PROJECT_NAME/REQUIREMENTS.md"
echo "   3. 编辑 .planning/$PROJECT_NAME/ROADMAP.md"
echo "   4. 开始 Phase 1 研究"
echo ""
echo "📖 查看快速启动指南:"
echo "   cat templates/research-project/QUICKSTART.md"
echo ""
