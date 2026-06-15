#!/usr/bin/env bash
# =============================================================================
# Suite de testes da API — Easy!Appointments
# Baseada nos dados reais do banco de dados
# =============================================================================

BASE="http://localhost/api/v1"
TOKEN="test-token-ea-2026"
H_AUTH="Authorization: Bearer $TOKEN"
H_CT="Content-Type: application/json"

# IDs reais (confirmados no banco)
ADMIN_ID=1           # John Doe — admin (sem working_plan)
PROVIDER_ID=2        # Jane Doe — provider
CUSTOMER_A_ID=3      # James Doe
CUSTOMER_B_ID=4      # Fulano Tal
SECRETARY_ID=5       # teste teste

COMPANY_A_ID=2       # EMPRESA A — todos os dias null
COMPANY_B_ID=3       # EMPRESA B — sexta 09:00-18:00
COMPANY_C_ID=4       # EMPRESA C — todos os dias null
COMPANY_D_ID=5       # EMPRESA D — plano NULL (sem entrada)

SERVICE_A_ID=1       # Service (30 min)
SERVICE_B_ID=2       # Service 2 (30 min)

# Plano particular Jane: seg/ter/qua 08:00-17:00
DATE_SEG="2026-06-15"   # Segunda
DATE_TER="2026-06-16"   # Terça
DATE_QUA="2026-06-17"   # Quarta
DATE_QUI="2026-06-18"   # Quinta  — null no plano particular
DATE_SEX="2026-06-19"   # Sexta   — EMPRESA B 09:00-18:00
DATE_SAB="2026-06-20"   # Sábado  — null em tudo
DATE_DOM="2026-06-14"   # Domingo — null em tudo

PASS=0; FAIL=0; TOTAL=0
CREATED_IDS=()

# ─── helpers ──────────────────────────────────────────────────────────────────

ok()   { PASS=$((PASS+1)); TOTAL=$((TOTAL+1)); echo "  ✓  $1"; }
fail() { FAIL=$((FAIL+1)); TOTAL=$((TOTAL+1)); echo "  ✗  $1"; echo "     → $2"; }

section() {
    echo ""
    echo "══════════════════════════════════════════════════════════════"
    echo "  $*"
    echo "══════════════════════════════════════════════════════════════"
}

call() {
    local method="$1" path="$2" data="$3"
    case "$method" in
        POST|PUT) curl -s -o /tmp/ea_resp.json -w "%{http_code}" \
                    -X "$method" -H "$H_AUTH" -H "$H_CT" -d "$data" "$BASE/$path" ;;
        DELETE)   curl -s -o /tmp/ea_resp.json -w "%{http_code}" \
                    -X DELETE -H "$H_AUTH" "$BASE/$path" ;;
        *)        curl -s -o /tmp/ea_resp.json -w "%{http_code}" \
                    -H "$H_AUTH" "$BASE/$path" ;;
    esac
}

body()  { cat /tmp/ea_resp.json 2>/dev/null; }
jget()  { body | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('$1',''))" 2>/dev/null; }
jlen()  { body | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null; }
jpath() { body | python3 -c "
import sys,json
d=json.load(sys.stdin)
for k in '$1'.split('.'): d=d[k] if isinstance(d,dict) else d[int(k)]
print(d)
" 2>/dev/null; }

assert_code() {
    local label="$1" exp="$2" code="$3"
    if [[ "$code" == "$exp" || ( "$exp" == "200" && "$code" == "204" ) ]]; then
        ok "$label (HTTP $code)"
    else
        fail "$label" "esperado=$exp recebido=$code | $(body | head -c 150)"
    fi
}

slots() {
    local provider="$1" service="$2" date="$3" company="${4:-}"
    local url="availabilities?providerId=$provider&serviceId=$service&date=$date"
    [ -n "$company" ] && url="$url&companyId=$company"
    curl -s -H "$H_AUTH" "$BASE/$url" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null
}

first_slot() {
    local provider="$1" service="$2" date="$3" company="${4:-}"
    local url="availabilities?providerId=$provider&serviceId=$service&date=$date"
    [ -n "$company" ] && url="$url&companyId=$company"
    curl -s -H "$H_AUTH" "$BASE/$url" | python3 -c "import sys,json; s=json.load(sys.stdin); print(s[0] if s else '')" 2>/dev/null
}

add_minutes() {
    python3 -c "
from datetime import datetime, timedelta
s=datetime.strptime('$1 $2','%Y-%m-%d %H:%M')
print((s+timedelta(minutes=$3)).strftime('%Y-%m-%d %H:%M:%S'))
"
}

# ══════════════════════════════════════════════════════════════════════════════
section "1. AUTENTICAÇÃO"
# ══════════════════════════════════════════════════════════════════════════════

code=$(curl -s -o /dev/null -w "%{http_code}" -H "$H_AUTH" "$BASE/providers")
assert_code "Bearer token válido aceito" "200" "$code"

code=$(curl -s -o /dev/null -w "%{http_code}" "$BASE/providers")
assert_code "Sem token retorna 401" "401" "$code"

code=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer TOKEN-ERRADO" "$BASE/providers")
assert_code "Token inválido retorna 401" "401" "$code"

code=$(curl -s -o /dev/null -w "%{http_code}" \
    -u "administrator:$(docker compose -f /home/eriksonlima/easyappointments/docker-compose.yml exec -T mysql mysql -u root -psecret easyappointments -sN -e "SELECT value FROM ea_user_settings WHERE id_users=1 LIMIT 1;" 2>/dev/null | head -1)" \
    "$BASE/providers" 2>/dev/null)
# Só valida se a chamada chegou ao servidor (2xx ou 4xx, não 000)
[[ "$code" != "000" ]] && ok "Basic Auth chegou ao servidor (HTTP $code)" || fail "Basic Auth não conectou" "HTTP $code"

# ══════════════════════════════════════════════════════════════════════════════
section "2. ADMINS"
# ══════════════════════════════════════════════════════════════════════════════

code=$(call GET "admins"); assert_code "GET /admins lista" "200" "$code"
count=$(jlen); [[ ${count:-0} -ge 1 ]] && ok "  → $count admin(s) encontrado(s)" || fail "Deveria ter admins" "count=$count"

code=$(call GET "admins/$ADMIN_ID"); assert_code "GET /admins/$ADMIN_ID (John Doe)" "200" "$code"
[[ "$(jget firstName)" == "John" ]] && ok "  → firstName=John" || fail "firstName incorreto" "$(jget firstName)"
[[ "$(jget lastName)"  == "Doe"  ]] && ok "  → lastName=Doe"   || fail "lastName incorreto"  "$(jget lastName)"

code=$(call GET "admins/99999"); assert_code "GET /admins/99999 (inexistente) retorna 404" "404" "$code"

# ══════════════════════════════════════════════════════════════════════════════
section "3. CUSTOMERS"
# ══════════════════════════════════════════════════════════════════════════════

code=$(call GET "customers"); assert_code "GET /customers lista" "200" "$code"
count=$(jlen); [[ ${count:-0} -ge 2 ]] && ok "  → $count customer(s) encontrado(s)" || fail "Deveria ter clientes" "count=$count"

code=$(call GET "customers/$CUSTOMER_A_ID"); assert_code "GET /customers/$CUSTOMER_A_ID (James Doe)" "200" "$code"
[[ "$(jget firstName)" == "James" ]] && ok "  → firstName=James" || fail "firstName incorreto" "$(jget firstName)"

code=$(call GET "customers/$CUSTOMER_B_ID"); assert_code "GET /customers/$CUSTOMER_B_ID (Fulano Tal)" "200" "$code"
[[ "$(jget firstName)" == "Fulano" ]] && ok "  → firstName=Fulano" || fail "firstName incorreto" "$(jget firstName)"

# CRUD customer temporário
TS=$(date +%s)
code=$(call POST "customers" "{\"firstName\":\"Temp\",\"lastName\":\"Test\",\"email\":\"temp-$TS@test.com\",\"phone\":\"+5511900000000\",\"timezone\":\"UTC\"}")
assert_code "POST /customers cria customer temporário" "201" "$code"
TEMP_CUST_ID=$(jget id)
[[ -n "$TEMP_CUST_ID" && "$TEMP_CUST_ID" != "None" ]] && ok "  → id=$TEMP_CUST_ID criado" || fail "ID não retornado" "$(body | head -c 100)"

if [[ -n "$TEMP_CUST_ID" && "$TEMP_CUST_ID" != "None" ]]; then
    code=$(call PUT "customers/$TEMP_CUST_ID" "{\"firstName\":\"TempUp\",\"lastName\":\"Test\",\"email\":\"temp-$TS@test.com\",\"phone\":\"+5511900000000\",\"timezone\":\"UTC\"}")
    assert_code "PUT /customers/$TEMP_CUST_ID atualiza" "200" "$code"
    [[ "$(jget firstName)" == "TempUp" ]] && ok "  → firstName atualizado para 'TempUp'" || fail "firstName não atualizou" "$(jget firstName)"

    code=$(call DELETE "customers/$TEMP_CUST_ID"); assert_code "DELETE /customers/$TEMP_CUST_ID" "200" "$code"
fi

# ══════════════════════════════════════════════════════════════════════════════
section "4. SERVICES"
# ══════════════════════════════════════════════════════════════════════════════

code=$(call GET "services"); assert_code "GET /services lista" "200" "$code"
count=$(jlen); [[ ${count:-0} -ge 2 ]] && ok "  → $count serviço(s) encontrado(s)" || fail "Deveria ter serviços" "count=$count"

code=$(call GET "services/$SERVICE_A_ID"); assert_code "GET /services/$SERVICE_A_ID (Service)" "200" "$code"
[[ "$(jget name)" == "Service" ]] && ok "  → name=Service" || fail "name incorreto" "$(jget name)"
[[ "$(jget duration)" == "30" ]]  && ok "  → duration=30"  || fail "duration incorreto" "$(jget duration)"

code=$(call GET "services/$SERVICE_B_ID"); assert_code "GET /services/$SERVICE_B_ID (Service 2)" "200" "$code"
[[ "$(jget name)" == "Service 2" ]] && ok "  → name=Service 2" || fail "name incorreto" "$(jget name)"

# ══════════════════════════════════════════════════════════════════════════════
section "5. PROVIDERS"
# ══════════════════════════════════════════════════════════════════════════════

code=$(call GET "providers"); assert_code "GET /providers lista" "200" "$code"
count=$(jlen); [[ ${count:-0} -ge 1 ]] && ok "  → $count provider(s) encontrado(s)" || fail "Deveria ter providers" "count=$count"

code=$(call GET "providers/$PROVIDER_ID"); assert_code "GET /providers/$PROVIDER_ID (Jane Doe)" "200" "$code"
[[ "$(jget firstName)" == "Jane" ]] && ok "  → firstName=Jane" || fail "firstName incorreto" "$(jget firstName)"
[[ "$(jget lastName)"  == "Doe"  ]] && ok "  → lastName=Doe"   || fail "lastName incorreto"  "$(jget lastName)"

# Serviços do provider
services_json=$(body | python3 -c "import sys,json; d=json.load(sys.stdin); print(json.dumps(d.get('services',[])))" 2>/dev/null)
has_s1=$(echo "$services_json" | python3 -c "import sys,json; l=json.load(sys.stdin); print('yes' if 1 in l else 'no')" 2>/dev/null)
[[ "$has_s1" == "yes" ]] && ok "  → provider vinculado ao Service (id=1)" || fail "Service id=1 não encontrado nos serviços do provider" "$services_json"

# ══════════════════════════════════════════════════════════════════════════════
section "6. SECRETÁRIOS"
# ══════════════════════════════════════════════════════════════════════════════

code=$(call GET "secretaries"); assert_code "GET /secretaries lista" "200" "$code"
count=$(jlen); [[ ${count:-0} -ge 1 ]] && ok "  → $count secretário(s) encontrado(s)" || fail "Deveria ter secretários" "count=$count"

code=$(call GET "secretaries/$SECRETARY_ID"); assert_code "GET /secretaries/$SECRETARY_ID (teste)" "200" "$code"
[[ "$(jget firstName)" == "teste" ]] && ok "  → firstName=teste" || fail "firstName incorreto" "$(jget firstName)"

# Verificar campo companies
companies_json=$(body | python3 -c "import sys,json; d=json.load(sys.stdin); print(json.dumps(d.get('companies','MISSING')))" 2>/dev/null)
[[ "$companies_json" != "MISSING" ]] && ok "  → campo 'companies' presente na resposta" || fail "Campo 'companies' ausente" ""
has_ca=$(echo "$companies_json" | python3 -c "import sys,json; l=json.load(sys.stdin); print('yes' if $COMPANY_A_ID in [int(x) for x in l] else 'no')" 2>/dev/null)
[[ "$has_ca" == "yes" ]] && ok "  → vinculado à EMPRESA A (id=$COMPANY_A_ID)" || fail "EMPRESA A não encontrada em companies" "$companies_json"

# Verificar campo providers
providers_json=$(body | python3 -c "import sys,json; d=json.load(sys.stdin); print(json.dumps(d.get('providers','MISSING')))" 2>/dev/null)
[[ "$providers_json" != "MISSING" ]] && ok "  → campo 'providers' presente na resposta" || fail "Campo 'providers' ausente" ""
has_p=$(echo "$providers_json" | python3 -c "import sys,json; l=json.load(sys.stdin); print('yes' if $PROVIDER_ID in [int(x) for x in l] else 'no')" 2>/dev/null)
[[ "$has_p" == "yes" ]] && ok "  → vinculado ao provider Jane Doe (id=$PROVIDER_ID)" || fail "Provider não encontrado" "$providers_json"

# ══════════════════════════════════════════════════════════════════════════════
section "7. COMPANIES"
# ══════════════════════════════════════════════════════════════════════════════

code=$(call GET "companies"); assert_code "GET /companies lista" "200" "$code"
count=$(jlen); [[ ${count:-0} -ge 4 ]] && ok "  → $count empresa(s) encontrada(s)" || fail "Deveria ter ao menos 4 empresas" "count=$count"

for CID in $COMPANY_A_ID $COMPANY_B_ID $COMPANY_C_ID $COMPANY_D_ID; do
    code=$(call GET "companies/$CID")
    assert_code "GET /companies/$CID" "200" "$code"
    cname=$(jget name)
    [[ -n "$cname" ]] && ok "  → name='$cname'" || fail "Campo name ausente para company $CID" ""
done

code=$(call GET "companies/99999"); assert_code "GET /companies/99999 (inexistente) retorna 404" "404" "$code"

# CRUD temporário de empresa
TS2=$(date +%s)
code=$(call POST "companies" "{\"name\":\"EMPRESA TEMP\",\"slug\":\"empresa-temp-$TS2\",\"email\":\"temp@empresa.com\",\"timezone\":\"UTC\"}")
assert_code "POST /companies cria empresa temporária" "201" "$code"
TEMP_CO_ID=$(jget id)
[[ -n "$TEMP_CO_ID" && "$TEMP_CO_ID" != "None" ]] && ok "  → id=$TEMP_CO_ID criado" || fail "ID não retornado" ""

if [[ -n "$TEMP_CO_ID" && "$TEMP_CO_ID" != "None" ]]; then
    code=$(call PUT "companies/$TEMP_CO_ID" "{\"name\":\"EMPRESA TEMP UP\",\"slug\":\"empresa-temp-$TS2\",\"timezone\":\"UTC\"}")
    assert_code "PUT /companies/$TEMP_CO_ID atualiza" "200" "$code"
    [[ "$(jget name)" == "EMPRESA TEMP UP" ]] && ok "  → name atualizado para 'EMPRESA TEMP UP'" || fail "name não atualizou" "$(jget name)"

    code=$(call DELETE "companies/$TEMP_CO_ID"); assert_code "DELETE /companies/$TEMP_CO_ID" "200" "$code"
fi

# ══════════════════════════════════════════════════════════════════════════════
section "8. WORKING PLAN — ENDPOINT DEDICADO"
# ══════════════════════════════════════════════════════════════════════════════

# Working plan particular (personal) de Jane Doe
code=$(call GET "companies/providers/$PROVIDER_ID/working_plan")
assert_code "GET working_plan particular de Jane Doe" "200" "$code"
wp_mon=$(body | python3 -c "import sys,json; d=json.load(sys.stdin); wp=d.get('workingPlan',{}); m=wp.get('monday',None); print(m['start'] if m else 'null')" 2>/dev/null)
[[ "$wp_mon" == "08:00" ]] && ok "  → monday.start=08:00 (correto)" || fail "monday.start incorreto no plano particular" "got=$wp_mon"

wp_thu=$(body | python3 -c "import sys,json; d=json.load(sys.stdin); wp=d.get('workingPlan',{}); t=wp.get('thursday',None); print('null' if t is None else t)" 2>/dev/null)
[[ "$wp_thu" == "null" ]] && ok "  → thursday=null (não trabalha na quinta — correto)" || fail "thursday deveria ser null no plano particular" "got=$wp_thu"

# Working plan EMPRESA A (todos null)
code=$(call GET "companies/$COMPANY_A_ID/providers/$PROVIDER_ID/working_plan")
assert_code "GET working_plan Jane Doe na EMPRESA A" "200" "$code"
wp_all_null=$(body | python3 -c "
import sys, json
d = json.load(sys.stdin)
wp = d.get('workingPlan', {})
all_null = all(v is None for v in wp.values())
print('yes' if all_null else 'no')
" 2>/dev/null)
[[ "$wp_all_null" == "yes" ]] && ok "  → EMPRESA A: todos os dias são null (sem horário)" || fail "EMPRESA A deveria ter todos os dias null" ""

# Working plan EMPRESA B (sexta 09:00-18:00)
code=$(call GET "companies/$COMPANY_B_ID/providers/$PROVIDER_ID/working_plan")
assert_code "GET working_plan Jane Doe na EMPRESA B" "200" "$code"
wp_fri=$(body | python3 -c "import sys,json; d=json.load(sys.stdin); wp=d.get('workingPlan',{}); f=wp.get('friday',None); print(f['start'] if f else 'null')" 2>/dev/null)
[[ "$wp_fri" == "09:00" ]] && ok "  → friday.start=09:00 na EMPRESA B (correto)" || fail "EMPRESA B friday.start incorreto" "got=$wp_fri"

# Working plan EMPRESA D (NULL — sem plano armazenado)
code=$(call GET "companies/$COMPANY_D_ID/providers/$PROVIDER_ID/working_plan")
assert_code "GET working_plan Jane Doe na EMPRESA D (sem plano)" "200" "$code"

# ══════════════════════════════════════════════════════════════════════════════
section "9. DISPONIBILIDADE — PLANO PARTICULAR"
# ══════════════════════════════════════════════════════════════════════════════
# Jane Doe: seg/ter/qua 08:00-17:00, qui/sex/sab/dom = null

for DATE_OK in "$DATE_SEG" "$DATE_TER" "$DATE_QUA"; do
    n=$(slots $PROVIDER_ID $SERVICE_A_ID "$DATE_OK")
    [[ ${n:-0} -gt 0 ]] && ok "Particular — $DATE_OK: $n slots disponíveis" \
                          || fail "Particular — $DATE_OK deveria ter slots" "n=$n"
done

for DATE_NULL in "$DATE_QUI" "$DATE_SEX" "$DATE_SAB" "$DATE_DOM"; do
    n=$(slots $PROVIDER_ID $SERVICE_A_ID "$DATE_NULL")
    [[ ${n:-0} -eq 0 ]] && ok "Particular — $DATE_NULL: 0 slots (dia null)" \
                          || fail "Particular — $DATE_NULL deveria ter 0 slots" "n=$n"
done

# Com Service 2 também
n=$(slots $PROVIDER_ID $SERVICE_B_ID "$DATE_SEG")
[[ ${n:-0} -gt 0 ]] && ok "Particular — segunda com Service 2: $n slots" || fail "Service 2 deveria ter slots na segunda" "n=$n"

# Usuário admin (sem plano): deve retornar 0 sem crash
n=$(slots $ADMIN_ID $SERVICE_A_ID "$DATE_SEG")
code=$(curl -s -o /dev/null -w "%{http_code}" -H "$H_AUTH" "$BASE/availabilities?providerId=$ADMIN_ID&serviceId=$SERVICE_A_ID&date=$DATE_SEG")
[[ "$code" == "200" ]] && ok "providerId=$ADMIN_ID (admin, sem plano): HTTP 200 sem crash" || fail "Admin com providerId deveria retornar 200" "HTTP $code"
[[ ${n:-0} -eq 0 ]] && ok "  → retorna 0 slots (admin não tem horários)" || fail "Admin deveria retornar 0 slots" "n=$n"

# ══════════════════════════════════════════════════════════════════════════════
section "10. DISPONIBILIDADE — PLANO POR EMPRESA"
# ══════════════════════════════════════════════════════════════════════════════

# EMPRESA B: sexta com slots
n=$(slots $PROVIDER_ID $SERVICE_A_ID "$DATE_SEX" "$COMPANY_B_ID")
[[ ${n:-0} -gt 0 ]] && ok "EMPRESA B — sexta $DATE_SEX: $n slots (09:00-18:00)" \
                      || fail "EMPRESA B sexta deveria ter slots" "n=$n"

# EMPRESA B: segunda sem slots (só tem sexta)
n=$(slots $PROVIDER_ID $SERVICE_A_ID "$DATE_SEG" "$COMPANY_B_ID")
[[ ${n:-0} -eq 0 ]] && ok "EMPRESA B — segunda: 0 slots (empresa só tem sexta)" \
                      || fail "EMPRESA B segunda deveria ter 0 slots" "n=$n"

# EMPRESA A: todos os dias null → 0 slots em qualquer dia
for DATE in "$DATE_SEG" "$DATE_SEX" "$DATE_DOM"; do
    n=$(slots $PROVIDER_ID $SERVICE_A_ID "$DATE" "$COMPANY_A_ID")
    [[ ${n:-0} -eq 0 ]] && ok "EMPRESA A — $DATE: 0 slots (todos dias null)" \
                          || fail "EMPRESA A $DATE deveria ter 0 slots" "n=$n"
done

# EMPRESA C: todos null → 0 slots
n=$(slots $PROVIDER_ID $SERVICE_A_ID "$DATE_SEX" "$COMPANY_C_ID")
[[ ${n:-0} -eq 0 ]] && ok "EMPRESA C — 0 slots (todos dias null)" || fail "EMPRESA C deveria ter 0 slots" "n=$n"

# EMPRESA D: plano NULL → 0 slots (sem plano cadastrado)
n=$(slots $PROVIDER_ID $SERVICE_A_ID "$DATE_SEX" "$COMPANY_D_ID")
[[ ${n:-0} -eq 0 ]] && ok "EMPRESA D — 0 slots (plano NULL não armazenado)" || fail "EMPRESA D deveria ter 0 slots" "n=$n"

# Isolamento: EMPRESA B sexta > 0, EMPRESA A sexta = 0
nb=$(slots $PROVIDER_ID $SERVICE_A_ID "$DATE_SEX" "$COMPANY_B_ID")
na=$(slots $PROVIDER_ID $SERVICE_A_ID "$DATE_SEX" "$COMPANY_A_ID")
[[ ${nb:-0} -gt 0 && ${na:-0} -eq 0 ]] \
    && ok "Isolamento: EMPRESA B sexta=$nb slots vs EMPRESA A sexta=$na slots" \
    || fail "Isolamento multi-empresa falhou" "EMPRESA B=$nb, EMPRESA A=$na"

# ══════════════════════════════════════════════════════════════════════════════
section "11. AGENDAMENTOS — CRUD COMPLETO"
# ══════════════════════════════════════════════════════════════════════════════

# Criar customer temporário para os testes
TS3=$(date +%s)
code=$(call POST "customers" "{\"firstName\":\"AptTest\",\"lastName\":\"User\",\"email\":\"apt-$TS3@test.com\",\"phone\":\"+5511911111111\",\"timezone\":\"UTC\"}")
assert_code "POST customer para testes de agendamento" "201" "$code"
TEMP_CUST2=$(jget id)
[[ -n "$TEMP_CUST2" && "$TEMP_CUST2" != "None" ]] && ok "  → customer id=$TEMP_CUST2" || { fail "Customer não criado" ""; TEMP_CUST2=""; }

CREATED_APTS=()

if [[ -n "$TEMP_CUST2" ]]; then
    # ── Agendamento 1: PARTICULAR — segunda
    SLOT1=$(first_slot $PROVIDER_ID $SERVICE_A_ID "$DATE_SEG")
    if [[ -n "$SLOT1" ]]; then
        END1=$(add_minutes "$DATE_SEG" "$SLOT1" 30)
        code=$(call POST "appointments" "{\"start\":\"$DATE_SEG ${SLOT1}:00\",\"end\":\"$END1\",\"serviceId\":$SERVICE_A_ID,\"providerId\":$PROVIDER_ID,\"customerId\":$TEMP_CUST2}")
        assert_code "POST agendamento PARTICULAR — $DATE_SEG $SLOT1" "201" "$code"
        APT1=$(jget id)
        [[ -n "$APT1" && "$APT1" != "None" ]] && { ok "  → id=$APT1 criado"; CREATED_APTS+=("$APT1"); } || fail "ID não retornado" ""

        # Verificar campo companyId = null
        co=$(jget companyId)
        [[ -z "$co" || "$co" == "None" ]] && ok "  → companyId=null (correto — agendamento particular)" || fail "companyId deveria ser null" "got=$co"
    else
        fail "Nenhum slot disponível na segunda para teste particular" ""
    fi

    # ── Agendamento 2: EMPRESA B — sexta
    SLOT2=$(first_slot $PROVIDER_ID $SERVICE_A_ID "$DATE_SEX" "$COMPANY_B_ID")
    if [[ -n "$SLOT2" ]]; then
        END2=$(add_minutes "$DATE_SEX" "$SLOT2" 30)
        code=$(call POST "appointments" "{\"start\":\"$DATE_SEX ${SLOT2}:00\",\"end\":\"$END2\",\"serviceId\":$SERVICE_A_ID,\"providerId\":$PROVIDER_ID,\"customerId\":$TEMP_CUST2,\"companyId\":$COMPANY_B_ID}")
        assert_code "POST agendamento EMPRESA B — $DATE_SEX $SLOT2" "201" "$code"
        APT2=$(jget id)
        [[ -n "$APT2" && "$APT2" != "None" ]] && { ok "  → id=$APT2 criado"; CREATED_APTS+=("$APT2"); } || fail "ID não retornado" ""

        # Verificar companyId persistido
        co=$(jget companyId)
        [[ "$co" == "$COMPANY_B_ID" ]] && ok "  → companyId=$co persistido (correto)" || fail "companyId não persistido" "got=$co"
    else
        fail "Nenhum slot disponível na sexta para EMPRESA B" ""
    fi

    # ── Agendamento 3: PARTICULAR — terça (Service 2)
    SLOT3=$(first_slot $PROVIDER_ID $SERVICE_B_ID "$DATE_TER")
    if [[ -n "$SLOT3" ]]; then
        END3=$(add_minutes "$DATE_TER" "$SLOT3" 30)
        code=$(call POST "appointments" "{\"start\":\"$DATE_TER ${SLOT3}:00\",\"end\":\"$END3\",\"serviceId\":$SERVICE_B_ID,\"providerId\":$PROVIDER_ID,\"customerId\":$CUSTOMER_A_ID}")
        assert_code "POST agendamento PARTICULAR — $DATE_TER $SLOT3 (Service 2, customer James)" "201" "$code"
        APT3=$(jget id)
        [[ -n "$APT3" && "$APT3" != "None" ]] && { ok "  → id=$APT3 criado"; CREATED_APTS+=("$APT3"); } || fail "ID não retornado" ""
    else
        fail "Nenhum slot na terça para Service 2" ""
    fi
fi

# ── GET /appointments lista
code=$(call GET "appointments"); assert_code "GET /appointments lista" "200" "$code"
count=$(jlen); [[ ${count:-0} -ge 1 ]] && ok "  → $count agendamento(s) na lista" || fail "Deveria ter agendamentos" "count=$count"

# ── GET agendamento por ID
if [[ ${#CREATED_APTS[@]} -ge 1 ]]; then
    ID="${CREATED_APTS[0]}"
    code=$(call GET "appointments/$ID"); assert_code "GET /appointments/$ID por ID" "200" "$code"
    [[ "$(jget id)" == "$ID" ]] && ok "  → id=$ID retornado corretamente" || fail "ID não bate" "$(jget id)"
fi

# ── PUT atualiza agendamento
if [[ ${#CREATED_APTS[@]} -ge 1 ]]; then
    ID="${CREATED_APTS[0]}"
    code=$(call GET "appointments/$ID")
    original_start=$(jget start)
    original_end=$(jget end)
    original_service=$(jget serviceId)
    original_provider=$(jget providerId)
    original_customer=$(jget customerId)

    code=$(call PUT "appointments/$ID" "{\"start\":\"$original_start\",\"end\":\"$original_end\",\"serviceId\":$original_service,\"providerId\":$original_provider,\"customerId\":$original_customer,\"notes\":\"Nota de teste\"}")
    assert_code "PUT /appointments/$ID adiciona nota" "200" "$code"
    [[ "$(jget notes)" == "Nota de teste" ]] && ok "  → notes atualizado" || fail "notes não atualizou" "$(jget notes)"
fi

# ── Slot ocupado: não deve aparecer na disponibilidade
if [[ ${#CREATED_APTS[@]} -ge 1 && -n "$SLOT1" ]]; then
    slots_after=$(slots $PROVIDER_ID $SERVICE_A_ID "$DATE_SEG")
    first_after=$(first_slot $PROVIDER_ID $SERVICE_A_ID "$DATE_SEG")
    [[ "$first_after" != "$SLOT1" ]] \
        && ok "Slot $SLOT1 ocupado: sumiu da disponibilidade (próximo=$first_after)" \
        || fail "Slot $SLOT1 ainda aparece disponível após agendamento" ""
fi

# ── GET inexistente
code=$(call GET "appointments/99999"); assert_code "GET /appointments/99999 retorna 404" "404" "$code"

# ══════════════════════════════════════════════════════════════════════════════
section "12. SETTINGS"
# ══════════════════════════════════════════════════════════════════════════════

code=$(call GET "settings"); assert_code "GET /settings lista" "200" "$code"
code=$(call GET "settings/company_name"); assert_code "GET /settings/company_name" "200" "$code"
code=$(call GET "settings/require_phone_number"); assert_code "GET /settings/require_phone_number" "200" "$code"
val=$(jget value); [[ "$val" == "1" ]] && ok "  → require_phone_number=1 (correto)" || fail "require_phone_number deveria ser 1" "got=$val"

# ══════════════════════════════════════════════════════════════════════════════
section "13. WEBHOOKS & BLOCKED PERIODS"
# ══════════════════════════════════════════════════════════════════════════════

code=$(call GET "webhooks"); assert_code "GET /webhooks lista" "200" "$code"
code=$(call GET "blocked_periods"); assert_code "GET /blocked_periods lista" "200" "$code"

# ══════════════════════════════════════════════════════════════════════════════
section "14. SERVICE CATEGORIES"
# ══════════════════════════════════════════════════════════════════════════════

code=$(call GET "service_categories"); assert_code "GET /service_categories lista" "200" "$code"

# ══════════════════════════════════════════════════════════════════════════════
section "15. LIMPEZA"
# ══════════════════════════════════════════════════════════════════════════════

for AID in "${CREATED_APTS[@]}"; do
    code=$(call DELETE "appointments/$AID"); assert_code "DELETE /appointments/$AID" "200" "$code"
done

if [[ -n "$TEMP_CUST2" && "$TEMP_CUST2" != "None" ]]; then
    code=$(call DELETE "customers/$TEMP_CUST2"); assert_code "DELETE customer temporário id=$TEMP_CUST2" "200" "$code"
fi

# ══════════════════════════════════════════════════════════════════════════════
section "RESULTADO FINAL"
# ══════════════════════════════════════════════════════════════════════════════

echo ""
echo "  Total  : $TOTAL"
echo "  Passou : $PASS"
echo "  Falhou : $FAIL"
echo ""
if [[ $FAIL -eq 0 ]]; then
    echo "  ✅  TODOS OS $PASS TESTES PASSARAM"
else
    PORCENT=$(python3 -c "print(round($PASS/$TOTAL*100))" 2>/dev/null)
    echo "  ❌  $FAIL TESTE(S) FALHARAM  ($PORCENT% de aprovação)"
fi
echo ""
