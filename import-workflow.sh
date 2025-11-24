#!/bin/bash

# Скрипт для импорта workflow в n8n через API
# Использование: ./import-workflow.sh <workflow-file.json> [api-key]

N8N_URL="${N8N_URL:-http://localhost:5678}"
WORKFLOW_FILE="${1}"
API_KEY="${2:-${N8N_API_KEY}}"

# Проверка аргументов
if [ -z "$WORKFLOW_FILE" ]; then
    echo "Использование: $0 <workflow-file.json> [api-key]"
    echo "Или установите переменную: export N8N_API_KEY=your-key"
    exit 1
fi

if [ ! -f "$WORKFLOW_FILE" ]; then
    echo "Ошибка: Файл $WORKFLOW_FILE не найден"
    exit 1
fi

if [ -z "$API_KEY" ]; then
    echo "Ошибка: API ключ не указан"
    echo "Укажите как аргумент: $0 $WORKFLOW_FILE your-api-key"
    echo "Или установите переменную: export N8N_API_KEY=your-key"
    exit 1
fi

echo "Импорт workflow из $WORKFLOW_FILE в $N8N_URL..."

# Импорт workflow
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
    -H "X-N8N-API-KEY: $API_KEY" \
    -H "Content-Type: application/json" \
    -d @"$WORKFLOW_FILE" \
    "$N8N_URL/api/v1/workflows")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -eq 200 ] || [ "$HTTP_CODE" -eq 201 ]; then
    echo "✓ Workflow успешно импортирован!"
    if command -v jq &> /dev/null; then
        echo "$BODY" | jq '{id: .id, name: .name, active: .active}'
    else
        echo "Ответ: $BODY"
    fi
    exit 0
else
    echo "✗ Ошибка импорта (HTTP $HTTP_CODE):"
    echo "$BODY"
    exit 1
fi

