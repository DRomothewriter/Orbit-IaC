#!/usr/bin/env bash
set -euo pipefail

REPO="${1:-DRomothewriter/Orbit-IaC}"
OWNER="${REPO%%/*}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

if ! command -v gh >/dev/null 2>&1; then
  echo "Error: GitHub CLI (gh) no está instalado. Instálalo con: brew install gh" >&2
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "Error: gh no está autenticado. Ejecuta: gh auth login" >&2
  exit 1
fi

echo "Aplicando políticas de seguridad DevSecOps en ${REPO}..."

apply_ruleset() {
  local file_path="$1"
  local ruleset_name
  ruleset_name="$(node -e "console.log(JSON.parse(require('fs').readFileSync(process.argv[1],'utf8')).name)" "$file_path")"

  local existing_id
  existing_id="$(gh api "/repos/${REPO}/rulesets" --jq ".[] | select(.name == \"${ruleset_name}\") | .id" | head -n 1 || true)"

  if [ -n "$existing_id" ]; then
    echo "Actualizando ruleset '${ruleset_name}' (ID: ${existing_id})..."
    gh api --method PUT "/repos/${REPO}/rulesets/${existing_id}" --input "$file_path" >/dev/null
  else
    echo "Creando ruleset '${ruleset_name}'..."
    gh api --method POST "/repos/${REPO}/rulesets" --input "$file_path" >/dev/null
  fi
}

apply_ruleset "${ROOT_DIR}/.github/rulesets/main-ruleset.json"
apply_ruleset "${ROOT_DIR}/.github/rulesets/dev-ruleset.json"
apply_ruleset "${ROOT_DIR}/.github/rulesets/tags-ruleset.json"

echo "Configurando environment 'production' con aprobación manual y restricción a main/v*..."
OWNER_ID="$(gh api "/users/${OWNER}" --jq '.id')"

ENV_PAYLOAD="$(cat <<EOF
{
  "wait_timer": 0,
  "prevent_self_review": false,
  "reviewers": [
    {
      "type": "User",
      "id": ${OWNER_ID}
    }
  ],
  "deployment_branch_policy": {
    "protected_branches": false,
    "custom_branch_policies": true
  }
}
EOF
)"

gh api --method PUT "/repos/${REPO}/environments/production" \
  --input - <<< "$ENV_PAYLOAD" >/dev/null

ensure_branch_policy() {
  local pattern="$1"
  local type="$2"
  local exists
  exists="$(gh api "/repos/${REPO}/environments/production/deployment-branch-policies" \
    --jq ".branch_policies[] | select(.name == \"${pattern}\" and .type == \"${type}\") | .id" | head -n 1 || true)"
  if [ -z "$exists" ]; then
    gh api --method POST "/repos/${REPO}/environments/production/deployment-branch-policies" \
      -f name="$pattern" -f type="$type" >/dev/null
  fi
}

ensure_branch_policy "main" "branch"
ensure_branch_policy "v*" "tag"

echo "Habilitando alertas de vulnerabilidades de Dependabot y seguridad del repositorio..."
gh api --method PUT "/repos/${REPO}/vulnerability-alerts" >/dev/null 2>&1 || \
  echo "Aviso: no se pudieron habilitar vulnerability-alerts automáticamente (verifica permisos de admin)."
gh api --method PUT "/repos/${REPO}/automated-security-fixes" >/dev/null 2>&1 || \
  echo "Aviso: no se pudieron habilitar automated-security-fixes automáticamente."
gh api --method PATCH "/repos/${REPO}" \
  -f "security_and_analysis[secret_scanning][status]=enabled" \
  -f "security_and_analysis[secret_scanning_push_protection][status]=enabled" >/dev/null 2>&1 || \
  echo "Aviso: secret scanning / push protection requiere plan GitHub compatible o configuración manual en Settings > Code security."

echo "Políticas aplicadas correctamente en ${REPO}."
