#!/usr/bin/env bash
# =============================================================================
# Full Validation Tests — Easy!Appointments Multi-Company
# Testa via API + valida comportamento esperado
# =============================================================================

BASE_URL="http://localhost"
API_BASE="$BASE_URL/api/v1"
TOKEN="test-token-ea-2026"

# IDs do banco (confirmados)
PROVIDER_ID=2          # Jane Doe
SECRETARY_ID=5         # teste teste
ADMIN_ID=1             # John Doe
COMPANY_A_ID=2         # EMPRESA A (Jane: quinta 09:00-18:00)
COMPANY_B_ID=3         # EMPRESA B (sem horário definido)
SERVICE_ID=1           # Service

# Datas de teste
DATE_MONDAY="2026-06-15"    # Segunda — plano particular Jane: 08:00-17:00
DATE_THURSDAY="2026-06-18"  # Quinta  — plano EMPRESA A: 09:00-18:00
DATE_SUNDAY="2026-06-14"    # Domingo — sem trabalho em qualquer plano

PASS=0
FAIL=0
TOTAL=0

# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

ok() {
    PASS=$((PASS+1)); TOTAL=$((TOTAL+1))
    echo "  ✓  $1"
}

fail() {
    FAIL=$((FAIL+1)); TOTAL=$((TOTAL+1))
    echo "  ✗  $1"
    echo "     → $2"
}

section() {
    echo ""
    echo "══════════════════════════════════════════════════════════════════"
    echo "  $1"
    echo "══════════════════════════════════════════════════════════════════"
}

api_call() {
    local method="$1" path="$2" data="$3"
    if [ "$method" = "POST" ] || [ "$method" = "PUT" ]; then
        curl -s -o /tmp/ea_test_resp.json -w "%{http_code}" \
            -X "$method" \
            -H "Authorization: Bearer $TOKEN" \
            -H "Content-Type: application/json" \
            -d "$data" \
            "$API_BASE/$path"
    elif [ "$method" = "DELETE" ]; then
        curl -s -o /tmp/ea_test_resp.json -w "%{http_code}" \
            -X DELETE \
            -H "Authorization: Bearer $TOKEN" \
            "$API_BASE/$path"
    else
        curl -s -o /tmp/ea_test_resp.json -w "%{http_code}" \
            -H "Authorization: Bearer $TOKEN" \
            "$API_BASE/$path"
    fi
}

get_body() { cat /tmp/ea_test_resp.json 2>/dev/null; }

py_get() {
    # py_get <json_string> <key>
    echo "$1" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    val = d
    for k in '$2'.split('.'):
        val = val[k] if isinstance(val, dict) else val[int(k)]
    print(val)
except:
    print('')
" 2>/dev/null
}

py_len() {
    echo "$1" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null
}

py_in() {
    # py_in <json_string> <value>
    echo "$1" | python3 -c "
import sys, json
lst = json.load(sys.stdin)
print('yes' if $2 in [int(x) for x in lst] else 'no')
" 2>/dev/null
}

assert_code() {
    local label="$1" expected="$2" code="$3"
    # aceita 200 ou 204 quando esperado é 200 (DELETE pode retornar 204)
    if [ "$code" = "$expected" ] || ( [ "$expected" = "200" ] && [ "$code" = "204" ] ); then
        ok "$label (HTTP $code)"
    else
        fail "$label" "esperado HTTP $expected, recebido $code | body: $(get_body | head -c 200)"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
section "1. AUTENTICAÇÃO E ACESSO À API"
# ─────────────────────────────────────────────────────────────────────────────

code=$(api_call GET "providers")
assert_code "GET providers com token válido" "200" "$code"

code=$(curl -s -o /dev/null -w "%{http_code}" "$API_BASE/providers")
if [ "$code" = "401" ]; then
    ok "GET providers sem token retorna 401 (HTTP $code)"
else
    fail "GET sem token deveria retornar 401" "recebido HTTP $code (a API pode estar em modo aberto)"
fi

code=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer token-errado" "$API_BASE/providers")
if [ "$code" = "401" ]; then
    ok "GET providers com token inválido retorna 401 (HTTP $code)"
else
    fail "Token inválido deveria retornar 401" "recebido HTTP $code"
fi

# ─────────────────────────────────────────────────────────────────────────────
section "2. COMPANIES (CRUD)"
# ─────────────────────────────────────────────────────────────────────────────

code=$(api_call GET "companies")
body=$(get_body)
assert_code "GET companies lista" "200" "$code"

count=$(py_len "$body")
if [ "${count:-0}" -ge "1" ] 2>/dev/null; then
    ok "GET companies retorna ao menos 1 empresa ($count encontradas)"
else
    fail "GET companies deve ter empresas" "count=$count"
fi

code=$(api_call GET "companies/$COMPANY_A_ID")
body=$(get_body)
assert_code "GET company EMPRESA A" "200" "$code"

name=$(py_get "$body" "name")
if [ "$name" = "EMPRESA A" ]; then
    ok "EMPRESA A tem campo name='EMPRESA A'"
else
    fail "EMPRESA A name incorreto" "recebido='$name'"
fi

# Criação de empresa temporária
TS=$(date +%s)
NEW_CO_JSON="{\"name\":\"EMPRESA TESTE $TS\",\"slug\":\"empresa-teste-$TS\",\"email\":\"teste$TS@auto.com\",\"timezone\":\"UTC\"}"
code=$(api_call POST "companies" "$NEW_CO_JSON")
body=$(get_body)
assert_code "POST companies cria empresa" "201" "$code"

NEW_CO_ID=$(py_get "$body" "id")
if [ -n "$NEW_CO_ID" ] && [ "$NEW_CO_ID" != "" ] && [ "$NEW_CO_ID" != "None" ]; then
    ok "Empresa criada com id=$NEW_CO_ID"
    code=$(api_call DELETE "companies/$NEW_CO_ID")
    assert_code "DELETE company temporária" "200" "$code"
else
    fail "POST companies não retornou id" "body: $(echo $body | head -c 200)"
fi

# ─────────────────────────────────────────────────────────────────────────────
section "3. SECRETÁRIOS (CRUD + VÍNCULOS)"
# ─────────────────────────────────────────────────────────────────────────────

code=$(api_call GET "secretaries/$SECRETARY_ID")
body=$(get_body)
assert_code "GET secretário teste (id=$SECRETARY_ID)" "200" "$code"

fname=$(py_get "$body" "firstName")
[ "$fname" = "teste" ] && ok "Secretário firstName='teste'" || fail "firstName incorreto" "recebido='$fname'"

companies_json=$(echo "$body" | python3 -c "import sys,json; d=json.load(sys.stdin); print(json.dumps(d.get('companies',[])))" 2>/dev/null)
if [ "$companies_json" != "null" ] && [ -n "$companies_json" ]; then
    ok "Secretário API retorna campo 'companies'"
    in_a=$(py_in "$companies_json" "$COMPANY_A_ID")
    [ "$in_a" = "yes" ] && ok "Secretário vinculado à EMPRESA A (id=$COMPANY_A_ID)" || fail "Secretário deve estar vinculado à EMPRESA A" "companies=$companies_json"
else
    fail "Secretário API deve retornar campo 'companies'" "campo ausente ou null"
fi

providers_json=$(echo "$body" | python3 -c "import sys,json; d=json.load(sys.stdin); print(json.dumps(d.get('providers',[])))" 2>/dev/null)
in_p=$(py_in "$providers_json" "$PROVIDER_ID")
[ "$in_p" = "yes" ] && ok "Secretário vinculado ao provider Jane Doe (id=$PROVIDER_ID)" || fail "Secretário deve estar vinculado ao provider Jane Doe" "providers=$providers_json"

# Criação de secretário temporário com vínculo de empresa
TS2=$(date +%s)
NEW_SEC_JSON="{
  \"firstName\":\"SecTeste\",
  \"lastName\":\"Auto\",
  \"email\":\"sec-auto-$TS2@test.com\",
  \"providers\":[$PROVIDER_ID],
  \"companies\":[$COMPANY_A_ID],
  \"timezone\":\"UTC\",
  \"settings\":{\"username\":\"sec-auto-$TS2\",\"password\":\"Test@1234\",\"notifications\":false,\"calendarView\":\"default\"}
}"
code=$(api_call POST "secretaries" "$NEW_SEC_JSON")
body=$(get_body)
assert_code "POST secretaries cria secretário" "201" "$code"
NEW_SEC_ID=$(py_get "$body" "id")

if [ -n "$NEW_SEC_ID" ] && [ "$NEW_SEC_ID" != "" ] && [ "$NEW_SEC_ID" != "None" ]; then
    ok "Secretário criado id=$NEW_SEC_ID"

    # Verifica se companies foi persistido
    code2=$(api_call GET "secretaries/$NEW_SEC_ID")
    body2=$(get_body)
    companies2=$(echo "$body2" | python3 -c "import sys,json; d=json.load(sys.stdin); print(json.dumps(d.get('companies',[])))" 2>/dev/null)
    in_a2=$(py_in "$companies2" "$COMPANY_A_ID")
    [ "$in_a2" = "yes" ] && ok "Novo secretário: companies persistido corretamente" || fail "Novo secretário: companies não persistido" "companies=$companies2"

    code3=$(api_call DELETE "secretaries/$NEW_SEC_ID")
    assert_code "DELETE secretário temporário" "200" "$code3"
else
    fail "POST secretaries não retornou id" "body: $(echo $body | head -c 200)"
fi

# ─────────────────────────────────────────────────────────────────────────────
section "4. PROVIDERS"
# ─────────────────────────────────────────────────────────────────────────────

code=$(api_call GET "providers/$PROVIDER_ID")
body=$(get_body)
assert_code "GET provider Jane Doe (id=$PROVIDER_ID)" "200" "$code"

fname=$(py_get "$body" "firstName")
[ "$fname" = "Jane" ] && ok "Provider firstName='Jane'" || fail "Provider firstName incorreto" "recebido='$fname'"

# ─────────────────────────────────────────────────────────────────────────────
section "5. WORKING PLAN EMPRESA — ENDPOINT DEDICADO"
# ─────────────────────────────────────────────────────────────────────────────

code=$(api_call GET "companies/$COMPANY_A_ID/providers/$PROVIDER_ID/working_plan")
body=$(get_body)
assert_code "GET working_plan Jane Doe na EMPRESA A" "200" "$code"

thursday_json=$(echo "$body" | python3 -c "
import sys, json
d = json.load(sys.stdin)
wp = d.get('workingPlan', d.get('working_plan', {}))
t = wp.get('thursday', None) if isinstance(wp, dict) else None
print(json.dumps(t))
" 2>/dev/null)

if [ "$thursday_json" != "null" ] && [ -n "$thursday_json" ]; then
    ok "Working plan EMPRESA A tem plano para quinta-feira"
    start_h=$(echo "$thursday_json" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('start',''))" 2>/dev/null)
    end_h=$(echo "$thursday_json" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('end',''))" 2>/dev/null)
    ok "  Quinta: início=$start_h, fim=$end_h"
else
    fail "Working plan EMPRESA A deveria ter quinta-feira" "thursday=$thursday_json body=$(echo $body | head -c 200)"
fi

# ─────────────────────────────────────────────────────────────────────────────
section "6. DISPONIBILIDADE — PLANO PARTICULAR"
# ─────────────────────────────────────────────────────────────────────────────
# Jane: segunda-quarta 08:00-17:00 (plano particular)

code=$(api_call GET "availabilities?providerId=$PROVIDER_ID&serviceId=$SERVICE_ID&date=$DATE_MONDAY")
body=$(get_body)
assert_code "GET disponibilidade particular (segunda $DATE_MONDAY)" "200" "$code"
count=$(py_len "$body")
if [ "${count:-0}" -gt "0" ] 2>/dev/null; then
    ok "Segunda: $count slots no plano particular"
else
    fail "Segunda deveria ter slots no plano particular" "slots=$count body=$(echo $body | head -c 100)"
fi

code=$(api_call GET "availabilities?providerId=$PROVIDER_ID&serviceId=$SERVICE_ID&date=$DATE_THURSDAY")
body=$(get_body)
assert_code "GET disponibilidade particular (quinta $DATE_THURSDAY)" "200" "$code"
count=$(py_len "$body")
if [ "${count:-0}" -eq "0" ] 2>/dev/null; then
    ok "Quinta: 0 slots particular (quinta é null no plano particular)"
else
    fail "Quinta deveria ter 0 slots no plano particular" "slots=$count"
fi

code=$(api_call GET "availabilities?providerId=$PROVIDER_ID&serviceId=$SERVICE_ID&date=$DATE_SUNDAY")
body=$(get_body)
count=$(py_len "$body")
if [ "${count:-0}" -eq "0" ] 2>/dev/null; then
    ok "Domingo: 0 slots particular (não é dia de trabalho)"
else
    fail "Domingo deveria ter 0 slots" "slots=$count"
fi

# ─────────────────────────────────────────────────────────────────────────────
section "7. DISPONIBILIDADE — PLANO DA EMPRESA A"
# ─────────────────────────────────────────────────────────────────────────────
# EMPRESA A: apenas quinta-feira 09:00-18:00

code=$(api_call GET "availabilities?providerId=$PROVIDER_ID&serviceId=$SERVICE_ID&date=$DATE_THURSDAY&companyId=$COMPANY_A_ID")
body=$(get_body)
assert_code "GET disponibilidade EMPRESA A (quinta $DATE_THURSDAY)" "200" "$code"
count=$(py_len "$body")
if [ "${count:-0}" -gt "0" ] 2>/dev/null; then
    ok "Quinta: $count slots na EMPRESA A (09:00-18:00)"
else
    fail "Quinta deveria ter slots na EMPRESA A" "slots=$count body=$(echo $body | head -c 100)"
fi

code=$(api_call GET "availabilities?providerId=$PROVIDER_ID&serviceId=$SERVICE_ID&date=$DATE_MONDAY&companyId=$COMPANY_A_ID")
body=$(get_body)
count=$(py_len "$body")
if [ "${count:-0}" -eq "0" ] 2>/dev/null; then
    ok "Segunda: 0 slots na EMPRESA A (empresa só tem quinta)"
else
    fail "Segunda deveria ter 0 slots na EMPRESA A" "slots=$count"
fi

code=$(api_call GET "availabilities?providerId=$PROVIDER_ID&serviceId=$SERVICE_ID&date=$DATE_SUNDAY&companyId=$COMPANY_A_ID")
body=$(get_body)
count=$(py_len "$body")
if [ "${count:-0}" -eq "0" ] 2>/dev/null; then
    ok "Domingo: 0 slots na EMPRESA A (domingo é null no plano)"
else
    fail "Domingo deveria ter 0 slots na EMPRESA A" "slots=$count"
fi

# ─────────────────────────────────────────────────────────────────────────────
section "8. ISOLAMENTO MULTI-EMPRESA"
# ─────────────────────────────────────────────────────────────────────────────
# EMPRESA A: quinta 09:00-18:00 | EMPRESA B: sem plano → 0 slots

slots_a_body=$(curl -s -H "Authorization: Bearer $TOKEN" \
    "$API_BASE/availabilities?providerId=$PROVIDER_ID&serviceId=$SERVICE_ID&date=$DATE_THURSDAY&companyId=$COMPANY_A_ID")
slots_a=$(py_len "$slots_a_body")

slots_b_body=$(curl -s -H "Authorization: Bearer $TOKEN" \
    "$API_BASE/availabilities?providerId=$PROVIDER_ID&serviceId=$SERVICE_ID&date=$DATE_THURSDAY&companyId=$COMPANY_B_ID")
slots_b=$(py_len "$slots_b_body")

if [ "${slots_a:-0}" -gt "0" ] 2>/dev/null && [ "${slots_b:-0}" -eq "0" ] 2>/dev/null; then
    ok "Isolamento multi-empresa: EMPRESA A=$slots_a slots vs EMPRESA B=$slots_b slots"
else
    fail "Isolamento multi-empresa falhou" "EMPRESA A=$slots_a, EMPRESA B=$slots_b"
fi

# ─────────────────────────────────────────────────────────────────────────────
section "9. CRIAÇÃO DE AGENDAMENTOS VÁLIDOS VIA API"
# ─────────────────────────────────────────────────────────────────────────────

# Criar customer temporário
CUST_TS=$(date +%s)
code=$(api_call POST "customers" "{\"firstName\":\"Cliente\",\"lastName\":\"Teste\",\"email\":\"cliente-$CUST_TS@test.com\",\"phone\":\"+5511999990000\",\"timezone\":\"UTC\"}")
body=$(get_body)
CUST_ID=$(py_get "$body" "id")
if [ -n "$CUST_ID" ] && [ "$CUST_ID" != "" ] && [ "$CUST_ID" != "None" ]; then
    ok "Customer temporário criado id=$CUST_ID"
else
    fail "POST customers falhou" "body=$(echo $body | head -c 200)"
    CUST_ID=""
fi

# Agendamento PARTICULAR (segunda)
SLOTS_MON=$(curl -s -H "Authorization: Bearer $TOKEN" \
    "$API_BASE/availabilities?providerId=$PROVIDER_ID&serviceId=$SERVICE_ID&date=$DATE_MONDAY")
SLOT_MON=$(echo "$SLOTS_MON" | python3 -c "import sys,json; slots=json.load(sys.stdin); print(slots[0] if slots else '')" 2>/dev/null)
APPT_MON_ID=""

if [ -n "$SLOT_MON" ] && [ -n "$CUST_ID" ]; then
    END_MON=$(python3 -c "
from datetime import datetime, timedelta
s = datetime.strptime('$DATE_MONDAY $SLOT_MON', '%Y-%m-%d %H:%M')
print((s + timedelta(minutes=30)).strftime('%Y-%m-%d %H:%M:%S'))
" 2>/dev/null)
    code=$(api_call POST "appointments" "{
        \"start\": \"$DATE_MONDAY ${SLOT_MON}:00\",
        \"end\": \"$END_MON\",
        \"serviceId\": $SERVICE_ID,
        \"providerId\": $PROVIDER_ID,
        \"customerId\": $CUST_ID
    }")
    body=$(get_body)
    assert_code "POST appointment PARTICULAR ($DATE_MONDAY $SLOT_MON)" "201" "$code"
    APPT_MON_ID=$(py_get "$body" "id")
    [ -n "$APPT_MON_ID" ] && ok "Agendamento particular criado id=$APPT_MON_ID" || fail "ID não retornado" "$(echo $body | head -c 200)"
else
    fail "Nenhum slot disponível segunda para teste" "slots disponíveis: $SLOTS_MON"
fi

# Agendamento EMPRESA A (quinta)
SLOTS_THU=$(curl -s -H "Authorization: Bearer $TOKEN" \
    "$API_BASE/availabilities?providerId=$PROVIDER_ID&serviceId=$SERVICE_ID&date=$DATE_THURSDAY&companyId=$COMPANY_A_ID")
SLOT_THU=$(echo "$SLOTS_THU" | python3 -c "import sys,json; slots=json.load(sys.stdin); print(slots[0] if slots else '')" 2>/dev/null)
APPT_THU_ID=""

if [ -n "$SLOT_THU" ] && [ -n "$CUST_ID" ]; then
    END_THU=$(python3 -c "
from datetime import datetime, timedelta
s = datetime.strptime('$DATE_THURSDAY $SLOT_THU', '%Y-%m-%d %H:%M')
print((s + timedelta(minutes=30)).strftime('%Y-%m-%d %H:%M:%S'))
" 2>/dev/null)
    code=$(api_call POST "appointments" "{
        \"start\": \"$DATE_THURSDAY ${SLOT_THU}:00\",
        \"end\": \"$END_THU\",
        \"serviceId\": $SERVICE_ID,
        \"providerId\": $PROVIDER_ID,
        \"customerId\": $CUST_ID,
        \"companyId\": $COMPANY_A_ID
    }")
    body=$(get_body)
    assert_code "POST appointment EMPRESA A ($DATE_THURSDAY $SLOT_THU)" "201" "$code"
    APPT_THU_ID=$(py_get "$body" "id")
    [ -n "$APPT_THU_ID" ] && ok "Agendamento EMPRESA A criado id=$APPT_THU_ID" || fail "ID não retornado" "$(echo $body | head -c 200)"

    # Verificar companyId persiste no agendamento
    co_id=$(py_get "$body" "companyId")
    [ "$co_id" = "$COMPANY_A_ID" ] && ok "Agendamento EMPRESA A: companyId=$co_id persistido" || fail "companyId não persistido" "recebido='$co_id'"
else
    fail "Nenhum slot disponível quinta EMPRESA A" "slots: $SLOTS_THU"
fi

# ─────────────────────────────────────────────────────────────────────────────
section "10. SLOT OCUPADO SOME DA DISPONIBILIDADE"
# ─────────────────────────────────────────────────────────────────────────────

if [ -n "$APPT_MON_ID" ]; then
    SLOTS_AFTER=$(curl -s -H "Authorization: Bearer $TOKEN" \
        "$API_BASE/availabilities?providerId=$PROVIDER_ID&serviceId=$SERVICE_ID&date=$DATE_MONDAY")
    first_after=$(echo "$SLOTS_AFTER" | python3 -c "import sys,json; slots=json.load(sys.stdin); print(slots[0] if slots else '')" 2>/dev/null)
    if [ "$first_after" != "$SLOT_MON" ]; then
        ok "Slot $SLOT_MON ocupado: sumiu da disponibilidade"
    else
        fail "Slot ocupado ainda aparece na disponibilidade" "slot=$SLOT_MON ainda disponível"
    fi
fi

# ─────────────────────────────────────────────────────────────────────────────
section "11. LEITURA DE AGENDAMENTOS (GET)"
# ─────────────────────────────────────────────────────────────────────────────

code=$(api_call GET "appointments")
body=$(get_body)
assert_code "GET appointments lista" "200" "$code"
count=$(py_len "$body")
if [ "${count:-0}" -ge "1" ] 2>/dev/null; then
    ok "GET appointments: $count agendamento(s) encontrado(s)"
else
    fail "GET appointments deveria ter ao menos 1" "count=$count"
fi

if [ -n "$APPT_THU_ID" ]; then
    code=$(api_call GET "appointments/$APPT_THU_ID")
    body=$(get_body)
    assert_code "GET appointment EMPRESA A por id" "200" "$code"
    co_id=$(py_get "$body" "companyId")
    [ "$co_id" = "$COMPANY_A_ID" ] && ok "GET appointment retorna companyId=$co_id" || fail "companyId incorreto no GET" "recebido='$co_id'"
fi

# ─────────────────────────────────────────────────────────────────────────────
section "12. LIMPEZA DOS AGENDAMENTOS E CUSTOMER DE TESTE"
# ─────────────────────────────────────────────────────────────────────────────

for APPT_ID in "$APPT_MON_ID" "$APPT_THU_ID"; do
    if [ -n "$APPT_ID" ] && [ "$APPT_ID" != "None" ] && [ "$APPT_ID" != "" ]; then
        code=$(api_call DELETE "appointments/$APPT_ID")
        assert_code "DELETE agendamento id=$APPT_ID" "200" "$code"
    fi
done

if [ -n "$CUST_ID" ] && [ "$CUST_ID" != "None" ]; then
    code=$(api_call DELETE "customers/$CUST_ID")
    assert_code "DELETE customer de teste id=$CUST_ID" "200" "$code"
fi

# ─────────────────────────────────────────────────────────────────────────────
section "RESULTADO FINAL"
# ─────────────────────────────────────────────────────────────────────────────

echo ""
echo "  Total: $TOTAL | Passou: $PASS | Falhou: $FAIL"
echo ""

if [ "$FAIL" -eq "0" ]; then
    echo "  ✅  TODOS OS $PASS TESTES PASSARAM"
else
    echo "  ❌  $FAIL/$TOTAL TESTES FALHARAM"
fi

echo ""
echo "══════════════════════════════════════════════════════════════════"
echo "  CHECKLIST FRONTEND (validar manualmente no navegador)"
echo "══════════════════════════════════════════════════════════════════"
echo ""
echo "  [ ] 1. /secretaries — Ao abrir secretário 'teste':"
echo "         • Checkbox 'EMPRESA A' aparece marcado"
echo "         • Checkbox 'Jane Doe' (providers) aparece marcado"
echo ""
echo "  [ ] 2. /companies — Ao selecionar 'EMPRESA A':"
echo "         • Badge 'teste teste' aparece na seção Secretários"
echo ""
echo "  [ ] 3. /providers — Ao selecionar 'Jane Doe':"
echo "         • Badge 'teste teste' aparece na seção Secretários"
echo ""
echo "  [ ] 4. /calendar (logado como secretário 'teste' / senha: teste):"
echo "         • Seletor 'Empresa' aparece no modal de agendamento"
echo "         • Opções: 'Particular (sem empresa)' + 'EMPRESA A'"
echo "         • Selecionar 'EMPRESA A' → provider Jane Doe disponível"
echo "         • Selecionar 'Particular' → Jane Doe disponível"
echo ""
echo "  [ ] 5. /calendar (logado como provider 'janedoe'):"
echo "         • Seletor 'Empresa' NÃO aparece no modal"
echo "         • Provider dropdown mostra apenas 'Jane Doe'"
echo ""
echo "  [ ] 6. Validação de horário — fora do expediente (calendar como secretário):"
echo "         • Tentar agendar em $DATE_SUNDAY (domingo) para qualquer horário"
echo "         • Sistema deve exibir diálogo de aviso 'fora do horário de trabalho'"
echo "         • Confirmar → salva mesmo assim"
echo "         • Cancelar → não salva"
echo ""
echo "  [ ] 7. Horário válido — EMPRESA A na quinta $DATE_THURSDAY (09:00-18:00):"
echo "         • Agendamento criado sem aviso de horário"
echo ""
