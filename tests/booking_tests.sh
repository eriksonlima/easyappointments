#!/bin/bash
# ============================================================
# Testes de agendamento multi-empresa — Easy!Appointments
# Estado atual (atualizado conforme dados reais do banco)
# ============================================================
BASE="http://localhost"
TOKEN="test-token-ea-2026"
AUTH="Authorization: Bearer $TOKEN"
CT="Content-Type: application/json"
PASS=0; FAIL=0

# Estado real de Jane Doe:
#  Plano particular: Segunda 08-17, Terça 08-17, Quarta 08-18
#  EMPRESA A (id=2):  Quinta   09-18
#  EMPRESA B (id=3):  Sábado   09-18
#  EMPRESA C (id=4):  Sexta    09-18
#  EMPRESA D (id=5):  sem plano

# Datas (semana de 15/06/2026)
MON="2026-06-15"  # Segunda  — particular
TUE="2026-06-16"  # Terça    — particular
WED="2026-06-17"  # Quarta   — particular
THU="2026-06-18"  # Quinta   — EMPRESA A
FRI="2026-06-19"  # Sexta    — EMPRESA C
SAT="2026-06-20"  # Sábado   — EMPRESA B
SUN="2026-06-21"  # Domingo  — sem plano

PROVIDER=2; SVC=1
CO_A=2; CO_B=3; CO_C=4; CO_D=5

ok()   { echo "  ✅  PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "  ❌  FAIL: $1"; echo "       → $2"; FAIL=$((FAIL+1)); }

slots_count() { curl -s -H "$AUTH" "$1" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null; }

check_has_slots() {
  local label="$1" url="$2"
  local count; count=$(slots_count "$url")
  [[ "$count" -gt 0 ]] && ok "$label (${count} slots)" || fail "$label — esperava slots, recebeu 0"
}

check_no_slots() {
  local label="$1" url="$2"
  local count; count=$(slots_count "$url")
  [[ "$count" -eq 0 ]] && ok "$label (0 slots — correto)" || fail "$label — esperava 0 slots, recebeu $count"
}

check_http() {
  local label="$1" expected="$2" method="$3" url="$4" data="$5"
  local code
  if   [[ "$method" == "POST" ]];   then code=$(curl -s -o /tmp/ea_resp.json -w "%{http_code}" -X POST   -H "$AUTH" -H "$CT" -d "$data" "$url")
  elif [[ "$method" == "PUT" ]];    then code=$(curl -s -o /tmp/ea_resp.json -w "%{http_code}" -X PUT    -H "$AUTH" -H "$CT" -d "$data" "$url")
  elif [[ "$method" == "DELETE" ]]; then code=$(curl -s -o /tmp/ea_resp.json -w "%{http_code}" -X DELETE -H "$AUTH" "$url")
  else                                   code=$(curl -s -o /tmp/ea_resp.json -w "%{http_code}"           -H "$AUTH" "$url")
  fi
  local body; body=$(cat /tmp/ea_resp.json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('message','') or str(d)[:120])" 2>/dev/null)
  [[ "$code" == "$expected" ]] && ok "$label (HTTP $code)" || fail "$label — esperava HTTP $expected, recebeu $code" "$body"
}

echo ""
echo "============================================================"
echo " Easy!Appointments — Testes de Agendamento Multi-Empresa"
echo "============================================================"
echo " Plano de Jane:"
echo "   Particular  : Segunda, Terça, Quarta"
echo "   EMPRESA A   : Quinta"
echo "   EMPRESA B   : Sábado"
echo "   EMPRESA C   : Sexta"
echo "   EMPRESA D   : sem plano"
echo ""

# ──────────────────────────────────────────────────────────────
echo "[ 1. AVAILABILITIES — Plano Particular ]"
# ──────────────────────────────────────────────────────────────
URL_AV="$BASE/api/v1/availabilities?providerId=$PROVIDER&serviceId=$SVC"

check_has_slots "1.1 Segunda disponível (particular)"  "$URL_AV&date=$MON"
check_has_slots "1.2 Terça disponível (particular)"    "$URL_AV&date=$TUE"
check_has_slots "1.3 Quarta disponível (particular)"   "$URL_AV&date=$WED"
check_no_slots  "1.4 Quinta indisponível (particular)" "$URL_AV&date=$THU"
check_no_slots  "1.5 Sexta indisponível (particular)"  "$URL_AV&date=$FRI"
check_no_slots  "1.6 Sábado indisponível (particular)" "$URL_AV&date=$SAT"
check_no_slots  "1.7 Domingo indisponível (sem plano)" "$URL_AV&date=$SUN"

# ──────────────────────────────────────────────────────────────
echo ""
echo "[ 2. AVAILABILITIES — Plano por Empresa ]"
# ──────────────────────────────────────────────────────────────

check_has_slots "2.1 EMPRESA A: Quinta disponível"      "$URL_AV&date=$THU&companyId=$CO_A"
check_no_slots  "2.2 EMPRESA A: Segunda indisponível"   "$URL_AV&date=$MON&companyId=$CO_A"
check_no_slots  "2.3 EMPRESA A: Sábado indisponível"    "$URL_AV&date=$SAT&companyId=$CO_A"

check_has_slots "2.4 EMPRESA B: Sábado disponível"      "$URL_AV&date=$SAT&companyId=$CO_B"
check_no_slots  "2.5 EMPRESA B: Quinta indisponível"    "$URL_AV&date=$THU&companyId=$CO_B"

check_has_slots "2.6 EMPRESA C: Sexta disponível"       "$URL_AV&date=$FRI&companyId=$CO_C"
check_no_slots  "2.7 EMPRESA C: Segunda indisponível"   "$URL_AV&date=$MON&companyId=$CO_C"

check_no_slots  "2.8 EMPRESA D: sem plano (0 slots)"    "$URL_AV&date=$THU&companyId=$CO_D"

# ──────────────────────────────────────────────────────────────
echo ""
echo "[ 3. CLIENTES — Pré-requisito ]"
# ──────────────────────────────────────────────────────────────
check_http "3.1 Criar cliente de teste" "201" "POST" "$BASE/api/v1/customers" \
  '{"firstName":"Teste","lastName":"Agendamento","email":"teste.ag@example.com","phone":"999990000"}'
CUST_ID=$(python3 -c "import json; print(json.load(open('/tmp/ea_resp.json')).get('id',''))" 2>/dev/null)
echo "     id=$CUST_ID"

# ──────────────────────────────────────────────────────────────
echo ""
echo "[ 4. AGENDAMENTOS VÁLIDOS (campos camelCase) ]"
# ──────────────────────────────────────────────────────────────

# Slot: Segunda 09:00 — plano particular
check_http "4.1 Agendar 2ª particular (09:00)" "201" "POST" "$BASE/api/v1/appointments" \
  "{\"start\":\"$MON 09:00:00\",\"end\":\"$MON 09:30:00\",\"serviceId\":$SVC,\"providerId\":$PROVIDER,\"customerId\":$CUST_ID}"
A1=$(python3 -c "import json; print(json.load(open('/tmp/ea_resp.json')).get('id',''))" 2>/dev/null)

# Slot: Quinta 10:00 — EMPRESA A
check_http "4.2 Agendar 5ª EMPRESA A (10:00)" "201" "POST" "$BASE/api/v1/appointments" \
  "{\"start\":\"$THU 10:00:00\",\"end\":\"$THU 10:30:00\",\"serviceId\":$SVC,\"providerId\":$PROVIDER,\"customerId\":$CUST_ID}"
A2=$(python3 -c "import json; print(json.load(open('/tmp/ea_resp.json')).get('id',''))" 2>/dev/null)

# Slot: Sábado 11:00 — EMPRESA B
check_http "4.3 Agendar Sab EMPRESA B (11:00)" "201" "POST" "$BASE/api/v1/appointments" \
  "{\"start\":\"$SAT 11:00:00\",\"end\":\"$SAT 11:30:00\",\"serviceId\":$SVC,\"providerId\":$PROVIDER,\"customerId\":$CUST_ID}"
A3=$(python3 -c "import json; print(json.load(open('/tmp/ea_resp.json')).get('id',''))" 2>/dev/null)

echo "     ids criados: A1=$A1, A2=$A2, A3=$A3"

# ──────────────────────────────────────────────────────────────
echo ""
echo "[ 5. DUPLO AGENDAMENTO — slot ocupado some da disponibilidade ]"
# ──────────────────────────────────────────────────────────────

# Após agendar Segunda 09:00, aquele slot deve sumir
SLOTS_MON=$(slots_count "$URL_AV&date=$MON")
SLOTS_MON_BEFORE=35   # original antes do agendamento

# O count de slots deve ser menor (slot 09:00 ocupado, mas vizinhos ainda abertos)
# Não checa 0 porque é um slot de 30min em janela 08-17h
if [[ -n "$A1" ]] && [[ "$SLOTS_MON" -lt "$SLOTS_MON_BEFORE" ]]; then
  ok "5.1 Slots de 2ª reduziram após agendamento ($SLOTS_MON slots restantes)"
elif [[ -z "$A1" ]]; then
  fail "5.1 Agendamento A1 não foi criado — não é possível testar" ""
else
  fail "5.1 Slots de 2ª deveriam ter reduzido, mas ainda são $SLOTS_MON" ""
fi

# Slot da Quinta após agendamento EMPRESA A
SLOTS_THU=$(slots_count "$URL_AV&date=$THU&companyId=$CO_A")
if [[ -n "$A2" ]] && [[ "$SLOTS_THU" -lt 35 ]]; then
  ok "5.2 Slots de 5ª (EMPRESA A) reduziram após agendamento ($SLOTS_THU restantes)"
elif [[ -z "$A2" ]]; then
  fail "5.2 Agendamento A2 não foi criado — não é possível testar" ""
else
  fail "5.2 Slots de 5ª deveriam ter reduzido, mas ainda são $SLOTS_THU" ""
fi

# ──────────────────────────────────────────────────────────────
echo ""
echo "[ 6. CONSULTAR E VALIDAR AGENDAMENTOS ]"
# ──────────────────────────────────────────────────────────────

check_http "6.1 Listar agendamentos" "200" "GET" "$BASE/api/v1/appointments" ""
TOTAL=$(python3 -c "import json; print(len(json.load(open('/tmp/ea_resp.json'))))" 2>/dev/null)
echo "     Total: $TOTAL agendamento(s)"

[[ -n "$A1" ]] && check_http "6.2 GET agendamento 2ª (id=$A1)"    "200" "GET" "$BASE/api/v1/appointments/$A1" ""
[[ -n "$A2" ]] && check_http "6.3 GET agendamento 5ª (id=$A2)"    "200" "GET" "$BASE/api/v1/appointments/$A2" ""
[[ -n "$A3" ]] && check_http "6.4 GET agendamento Sab (id=$A3)"   "200" "GET" "$BASE/api/v1/appointments/$A3" ""

# ──────────────────────────────────────────────────────────────
echo ""
echo "[ 7. WORKING PLANS DA API ]"
# ──────────────────────────────────────────────────────────────

check_http "7.1 GET working plan EMPRESA A  (provider 2)" "200" "GET" "$BASE/api/v1/companies/$CO_A/providers/$PROVIDER/working_plan" ""
WP=$(python3 -c "import json; d=json.load(open('/tmp/ea_resp.json')); k=[day for day,v in d.get('working_plan',{}).items() if v]; print('dias ativos:',k)" 2>/dev/null)
echo "     EMPRESA A → $WP"

check_http "7.2 GET working plan particular (provider 2)" "200" "GET" "$BASE/api/v1/companies/providers/$PROVIDER/working_plan" ""
WP2=$(python3 -c "import json; d=json.load(open('/tmp/ea_resp.json')); k=[day for day,v in d.get('working_plan',{}).items() if v]; print('dias ativos:',k)" 2>/dev/null)
echo "     Particular → $WP2"

check_http "7.3 GET working plan EMPRESA B  (provider 2)" "200" "GET" "$BASE/api/v1/companies/$CO_B/providers/$PROVIDER/working_plan" ""
check_http "7.4 GET working plan EMPRESA C  (provider 2)" "200" "GET" "$BASE/api/v1/companies/$CO_C/providers/$PROVIDER/working_plan" ""

# ──────────────────────────────────────────────────────────────
echo ""
echo "[ 8. ISOLAMENTO MULTI-EMPRESA ]"
# ──────────────────────────────────────────────────────────────

check_http "8.1 Listar todas as empresas"  "200" "GET" "$BASE/api/v1/companies"     ""
check_http "8.2 GET EMPRESA A por ID"      "200" "GET" "$BASE/api/v1/companies/$CO_A" ""
check_http "8.3 GET EMPRESA B por ID"      "200" "GET" "$BASE/api/v1/companies/$CO_B" ""
check_http "8.4 GET EMPRESA C por ID"      "200" "GET" "$BASE/api/v1/companies/$CO_C" ""
check_http "8.5 GET providers via API"     "200" "GET" "$BASE/api/v1/providers"      ""

# ──────────────────────────────────────────────────────────────
echo ""
echo "[ 9. LIMPEZA ]"
# ──────────────────────────────────────────────────────────────

[[ -n "$A1" ]]      && check_http "9.1 Delete agendamento 2ª"  "204" "DELETE" "$BASE/api/v1/appointments/$A1" ""
[[ -n "$A2" ]]      && check_http "9.2 Delete agendamento 5ª"  "204" "DELETE" "$BASE/api/v1/appointments/$A2" ""
[[ -n "$A3" ]]      && check_http "9.3 Delete agendamento Sab" "204" "DELETE" "$BASE/api/v1/appointments/$A3" ""
[[ -n "$CUST_ID" ]] && check_http "9.4 Delete cliente teste"   "204" "DELETE" "$BASE/api/v1/customers/$CUST_ID" ""

# ──────────────────────────────────────────────────────────────
echo ""
echo "============================================================"
echo " RESULTADO: $PASS passou(aram) | $FAIL falhou(aram)"
echo "============================================================"
[[ $FAIL -eq 0 ]] && echo " ✅  TODOS OS TESTES PASSARAM" || echo " ⚠️   ATENÇÃO: $FAIL teste(s) falharam"
echo ""
