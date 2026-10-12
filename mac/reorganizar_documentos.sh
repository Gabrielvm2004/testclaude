#!/bin/bash
# Reorganiza a pasta Documentos no formato numerado combinado:
#   0 LEIA-ME · 1 TCC · 2 América-PE · 3 Benfica · 4 Alunos · 5 Estudos ·
#   6 Faculdade · 7 Pessoal · 8 Projetos · 9 Arquivo · Scout (não muda)
#
# - Mostra o plano antes (abre no TextEdit) e só aplica se você confirmar.
# - Nunca apaga arquivos nem sobrescreve (se o destino já existir, ganha " (2)").
# - Só remove pastas que ficaram VAZIAS depois da mudança.
# - Cria um script para DESFAZER tudo.
#
# Como usar (no Terminal):  bash ~/Downloads/reorganizar_documentos.sh
# VERSAO 1

case "${LC_ALL:-${LC_CTYPE:-$LANG}}" in *UTF-8*|*utf8*) ;; *) export LC_ALL=en_US.UTF-8 ;; esac

DATA="$(date +%Y-%m-%d_%H-%M-%S)"
PLANO="$HOME/Downloads/PLANO_documentos_$DATA.txt"
DESFAZER="$HOME/Downloads/DESFAZER_documentos_$DATA.sh"
TMPD="$(mktemp -d)"
trap 'rm -rf "$TMPD"' EXIT

livre() {   # caminho -> caminho que ainda não existe
  local p="$1" k=2 base ext
  [ -e "$p" ] || { echo "$p"; return; }
  if [ -d "$p" ] || [[ "${p##*/}" != *.* ]]; then base="$p"; ext=""; else base="${p%.*}"; ext=".${p##*.}"; fi
  while [ -e "$base ($k)$ext" ]; do k=$((k + 1)); done
  echo "$base ($k)$ext"
}

sed -n "/^: <<'__LISTA__'$/,/^__LISTA__$/p" "$0" | sed '1d;$d' > "$TMPD/lista"

OP=(); SRC=(); DST=(); faltando=0
while IFS=$'\t' read -r op src dst; do
  [ -z "$op" ] && continue
  OP+=("$op"); SRC+=("$src"); DST+=("$dst")
  if [ "$op" = mv ] && [ ! -e "$HOME/$src" ]; then faltando=$((faltando + 1)); echo "$src" >> "$TMPD/faltando"; fi
done < "$TMPD/lista"

# ---------- Plano ----------
{
  echo "PLANO DE REORGANIZAÇÃO DOS DOCUMENTOS — $DATA"
  echo "Nada foi mudado ainda. Volte ao Terminal para confirmar."
  echo "Formato:  item   <-   de onde vem      (agrupado pela pasta nova)"
  echo
  i=0
  while [ $i -lt ${#OP[@]} ]; do
    if [ "${OP[$i]}" = mv ] && [ -e "$HOME/${SRC[$i]}" ]; then
      d="${DST[$i]%/*}"; d="${d#Documents/}"
      o="${SRC[$i]%/*}"; o="${o#Documents/}"
      printf '%s\t   %s   <-   %s\n' "$d" "${DST[$i]##*/}" "$o"
    fi
    i=$((i + 1))
  done | sort -t$'\t' -k1,1 -s | awk -F'\t' '$1!=g{g=$1; print "\n=== " g " ==="} {print $2}'
  if [ $faltando -gt 0 ]; then echo; echo "=== NÃO ENCONTRADOS (serão ignorados) ==="; cat "$TMPD/faltando"; fi
} > "$PLANO"

echo
echo "Itens a mover: $(( $(grep -c '<-' "$PLANO") ))"
[ $faltando -gt 0 ] && echo "Não encontrados (serão ignorados): $faltando"
echo "Por pasta nova (resumo):"
grep '^=== ' "$PLANO" | grep -v 'NÃO ENCONTRADOS' | sed 's/^=== //; s/ ===$//' | awk -F/ '{print $1}' | sort | uniq -c
[ -e "$HOME/Downloads/0 LEIA-ME - Mapa das pastas.pdf" ] || echo "Aviso: o mapa '0 LEIA-ME - Mapa das pastas.pdf' não está nos Downloads; o resto funciona normalmente."
echo
echo "O plano completo está em: $PLANO"
open -e "$PLANO" 2>/dev/null
printf "Aplicar? (s = sim / n = não) "
read -r ok
if [ "$ok" != "s" ] && [ "$ok" != "S" ]; then echo "Cancelado. Nada foi alterado."; exit 0; fi

# ---------- Aplica (o desfazer volta na ordem inversa) ----------
PASSOS="$TMPD/passos"; : > "$PASSOS"
gerar_desfazer() {
  { echo "#!/bin/bash"; echo "# Desfaz a reorganização dos Documentos feita em $DATA"
    awk '{a[NR]=$0} END{for(i=NR;i>=1;i--) print a[i]}' "$PASSOS"; } > "$DESFAZER"
}
trap 'gerar_desfazer; rm -rf "$TMPD"' EXIT

movidos=0; erros=0
i=0
while [ $i -lt ${#OP[@]} ]; do
  op="${OP[$i]}"; src="$HOME/${SRC[$i]}"; dst="$HOME/${DST[$i]}"
  i=$((i + 1))
  if [ "$op" = rmdir ]; then
    [ -d "$src" ] || continue
    rm -f "$src/.DS_Store" 2>/dev/null
    rmdir "$src" 2>/dev/null && printf 'mkdir -p %q\n' "$src" >> "$PASSOS"
    continue
  fi
  [ -e "$src" ] || continue
  mkdir -p "${dst%/*}"
  alvo="$(livre "$dst")"
  if mv "$src" "$alvo"; then
    printf 'mkdir -p %q && mv -n %q %q\n' "${src%/*}" "$alvo" "$src" >> "$PASSOS"
    movidos=$((movidos + 1))
  else
    erros=$((erros + 1))
  fi
done

echo
echo "Pronto! $movidos itens organizados."
[ $erros -gt 0 ] && echo "Atenção: $erros itens não puderam ser movidos (veja as mensagens acima)."
echo "Para desfazer:"
echo "  bash \"$DESFAZER\""
open "$HOME/Documents" 2>/dev/null
exit 0

: <<'__LISTA__'
mv	Documents/TCC/Referências/(RE)CONCEPTUALIZING MOVEMENT BEHAVIOR IN SPORT AS A PROBLEM-SOLVING ACTIVITY - Myszka, Yearby e Davids (2023).pdf	Documents/1 TCC/Referências/Dinâmica ecológica e ensino/(RE)CONCEPTUALIZING MOVEMENT BEHAVIOR IN SPORT AS A PROBLEM-SOLVING ACTIVITY - Myszka, Yearby e Davids (2023).pdf
mv	Documents/TCC/Referências/A EMERGÊNCIA DA TOMADA DE DECISÃO NO FUTEBOL - DA DECISÃO INDIVIDUAL PARA A COLETIVA - Duarte et al. (2010).pdf	Documents/1 TCC/Referências/Tomada de decisão e cognição/A EMERGÊNCIA DA TOMADA DE DECISÃO NO FUTEBOL - DA DECISÃO INDIVIDUAL PARA A COLETIVA - Duarte et al. (2010).pdf
mv	Documents/TCC/Referências/A HABILIDADE MOTORA PASSE E A ORGANIZAÇÃO HIERÁRQUICA EM EQUIPES DE FUTEBOL - Reis (2022) (tese).pdf	Documents/1 TCC/Referências/Jogos reduzidos e restrições/A HABILIDADE MOTORA PASSE E A ORGANIZAÇÃO HIERÁRQUICA EM EQUIPES DE FUTEBOL - Reis (2022) (tese).pdf
mv	Documents/TCC/Referências/A INFLUÊNCIA DA MANIPULAÇÃO DE TAREFA EM JOGOS REDUZIDOS SOBRE O COMPORTAMENTO CRIATIVO - Andrade (2023) (dissertação).pdf	Documents/1 TCC/Referências/Criatividade/A INFLUÊNCIA DA MANIPULAÇÃO DE TAREFA EM JOGOS REDUZIDOS SOBRE O COMPORTAMENTO CRIATIVO - Andrade (2023) (dissertação).pdf
mv	Documents/TCC/Referências/ABORDAGEM SISTÊMICA DO JOGO DE FUTEBOL - MODA OU NECESSIDADE - Garganta e Gréhaigne (1999).pdf	Documents/1 TCC/Referências/Dinâmica ecológica e ensino/ABORDAGEM SISTÊMICA DO JOGO DE FUTEBOL - MODA OU NECESSIDADE - Garganta e Gréhaigne (1999).pdf
mv	Documents/TCC/Referências/AN ECOLOGICAL PERSPECTIVE ON INTRA-TEAM COMMUNICATION IN TEAM SPORTS - Caso et al. (2026).pdf	Documents/1 TCC/Referências/Dinâmica ecológica e ensino/AN ECOLOGICAL PERSPECTIVE ON INTRA-TEAM COMMUNICATION IN TEAM SPORTS - Caso et al. (2026).pdf
mv	Documents/TCC/Referências/AN EXTENDED CHALLENGE-BASED FRAMEWORK FOR PRACTICE DESIGN IN SPORTS COACHING - Hodges e Lohse (2021).pdf	Documents/1 TCC/Referências/Dinâmica ecológica e ensino/AN EXTENDED CHALLENGE-BASED FRAMEWORK FOR PRACTICE DESIGN IN SPORTS COACHING - Hodges e Lohse (2021).pdf
mv	Documents/TCC/Referências/ANALISANDO O COMPORTAMENTO HOMEOSTÁTICO EM EQUIPES DE FUTEBOL DE ELITE (2026) [PT].pdf	Documents/1 TCC/Referências/Dinâmica ecológica e ensino/ANALISANDO O COMPORTAMENTO HOMEOSTÁTICO EM EQUIPES DE FUTEBOL DE ELITE (2026) [PT].pdf
mv	Documents/TCC/Referências/ANALYSING THE INFLUENCE OF NUMERICAL IMBALANCE ON INDIVIDUAL TACTICAL BEHAVIOUR IN SOCCER - Nunes et al. (2025).pdf	Documents/1 TCC/Referências/Jogos reduzidos e restrições/ANALYSING THE INFLUENCE OF NUMERICAL IMBALANCE ON INDIVIDUAL TACTICAL BEHAVIOUR IN SOCCER - Nunes et al. (2025).pdf
mv	Documents/TCC/Referências/APLICANDO DIFERENTES ESTRATÉGIAS DE MANIPULAÇÃO DE RESTRIÇÕES EM JOGOS REDUZIDOS - Góes, Machado et al. (2022) [PT].pdf	Documents/1 TCC/Referências/Jogos reduzidos e restrições/APLICANDO DIFERENTES ESTRATÉGIAS DE MANIPULAÇÃO DE RESTRIÇÕES EM JOGOS REDUZIDOS - Góes, Machado et al. (2022) [PT].pdf
mv	Documents/TCC/Referências/APPLYING DIFFERENT STRATEGIES OF TASK CONSTRAINT MANIPULATION IN SMALL-SIDED AND CONDITIONED GAMES - Machado et al. (2022).pdf	Documents/1 TCC/Referências/Jogos reduzidos e restrições/APPLYING DIFFERENT STRATEGIES OF TASK CONSTRAINT MANIPULATION IN SMALL-SIDED AND CONDITIONED GAMES - Machado et al. (2022).pdf
mv	Documents/TCC/Referências/COGNITION, EMOTION AND ACTION IN SPORT - AN ECOLOGICAL DYNAMICS PERSPECTIVE - Araújo, Davids e Renshaw (2020).pdf	Documents/1 TCC/Referências/Tomada de decisão e cognição/COGNITION, EMOTION AND ACTION IN SPORT - AN ECOLOGICAL DYNAMICS PERSPECTIVE - Araújo, Davids e Renshaw (2020).pdf
mv	Documents/TCC/Referências/COMPORTAMENTO TÁTICO EM PEQUENOS JOGOS NO FUTEBOL - CONHECIMENTO TÁTICO E SUPERIORIDADE NUMÉRICA - Praça et al. (2016).pdf	Documents/1 TCC/Referências/Jogos reduzidos e restrições/COMPORTAMENTO TÁTICO EM PEQUENOS JOGOS NO FUTEBOL - CONHECIMENTO TÁTICO E SUPERIORIDADE NUMÉRICA - Praça et al. (2016).pdf
mv	Documents/TCC/Referências/CONTEXTUALIZATION OF SOCCER ANALYSIS WITH TACTICAL PERIODIZATION AND MACHINE LEARNING - Biermann et al. (2025).pdf	Documents/1 TCC/Referências/Dinâmica ecológica e ensino/CONTEXTUALIZATION OF SOCCER ANALYSIS WITH TACTICAL PERIODIZATION AND MACHINE LEARNING - Biermann et al. (2025).pdf
mv	Documents/TCC/Referências/CREATIVE AND INTUITIVE DECISION-MAKING PROCESSES - BRAZILIAN AND GERMAN SOCCER COACHES AND PLAYERS - Klatt et al. (2019).pdf	Documents/1 TCC/Referências/Criatividade/CREATIVE AND INTUITIVE DECISION-MAKING PROCESSES - BRAZILIAN AND GERMAN SOCCER COACHES AND PLAYERS - Klatt et al. (2019).pdf
mv	Documents/TCC/Referências/DESENVOLVENDO RESTRIÇÕES DE TAREFAS PARA DIFERENTES FAIXAS ETÁRIAS NO FUTEBOL - REGRAS PARA FLUTUADORES [PT].pdf	Documents/1 TCC/Referências/Jogos reduzidos e restrições/DESENVOLVENDO RESTRIÇÕES DE TAREFAS PARA DIFERENTES FAIXAS ETÁRIAS NO FUTEBOL - REGRAS PARA FLUTUADORES [PT].pdf
mv	Documents/TCC/Referências/DEVELOPING COGNITIVE AND MOTOR DECISION-MAKING THROUGH TACTICAL PRINCIPLES AND SSGS IN YOUTH SOCCER - Machado et al. (2024).pdf	Documents/1 TCC/Referências/Jogos reduzidos e restrições/DEVELOPING COGNITIVE AND MOTOR DECISION-MAKING THROUGH TACTICAL PRINCIPLES AND SSGS IN YOUTH SOCCER - Machado et al. (2024).pdf
mv	Documents/TCC/Referências/DEVELOPING CREATIVITY TO ENHANCE HUMAN POTENTIAL IN SPORT - A WICKED TRANSDISCIPLINARY CHALLENGE - Vaughan et al. (2019).pdf	Documents/1 TCC/Referências/Criatividade/DEVELOPING CREATIVITY TO ENHANCE HUMAN POTENTIAL IN SPORT - A WICKED TRANSDISCIPLINARY CHALLENGE - Vaughan et al. (2019).pdf
mv	Documents/TCC/Referências/DISCOVERY LEARNING IN SPORTS - Raab et al. (2009).pdf	Documents/1 TCC/Referências/Tomada de decisão e cognição/DISCOVERY LEARNING IN SPORTS - Raab et al. (2009).pdf
mv	Documents/TCC/Referências/ECOLOGICAL DYNAMIC APPROACH AND YOUNG SOCCER PLAYER TRAINING - THE AIM IS THE FLEXIBLE BEHAVIOR - Sannicandro (2023).pdf	Documents/1 TCC/Referências/Dinâmica ecológica e ensino/ECOLOGICAL DYNAMIC APPROACH AND YOUNG SOCCER PLAYER TRAINING - THE AIM IS THE FLEXIBLE BEHAVIOR - Sannicandro (2023).pdf
mv	Documents/TCC/Referências/EFFECT OF AN INSIDE FLOATER ON SOCCER PLAYERS TACTICAL BEHAVIOUR IN SMALL SIDED GAMES - Moniz et al. (2020).pdf	Documents/1 TCC/Referências/Jogos reduzidos e restrições/EFFECT OF AN INSIDE FLOATER ON SOCCER PLAYERS TACTICAL BEHAVIOUR IN SMALL SIDED GAMES - Moniz et al. (2020).pdf
mv	Documents/TCC/Referências/EFFECTS OF A CREATIVE TEACHING-BASED TRAINING PROGRAMME ON TACTICAL KNOWLEDGE - Duda et al. (2026).pdf	Documents/1 TCC/Referências/Criatividade/EFFECTS OF A CREATIVE TEACHING-BASED TRAINING PROGRAMME ON TACTICAL KNOWLEDGE - Duda et al. (2026).pdf
mv	Documents/TCC/Referências/EM BUSCA DE PADRÕES DE JOGO DA FASE OFENSIVA EM PEQUENOS JOGOS DE FUTEBOL - Praça et al. (2017).pdf	Documents/1 TCC/Referências/Jogos reduzidos e restrições/EM BUSCA DE PADRÕES DE JOGO DA FASE OFENSIVA EM PEQUENOS JOGOS DE FUTEBOL - Praça et al. (2017).pdf
mv	Documents/TCC/Referências/EMBODIED COGNITION WITH AND WITHOUT MENTAL REPRESENTATIONS - EMBODIED CHOICES IN SPORTS - Raab (2019).pdf	Documents/1 TCC/Referências/Tomada de decisão e cognição/EMBODIED COGNITION WITH AND WITHOUT MENTAL REPRESENTATIONS - EMBODIED CHOICES IN SPORTS - Raab (2019).pdf
mv	Documents/TCC/Referências/ENGENHARIA DO JOGO.pdf	Documents/1 TCC/Referências/Dinâmica ecológica e ensino/ENGENHARIA DO JOGO.pdf
mv	Documents/TCC/Referências/FLEXIBLE DEFENSE SUCCEEDS CREATIVE ATTACKS - SIMULATION BASED ON POSITION DATA - Memmert, Imkamp e Perl (2021).pdf	Documents/1 TCC/Referências/Criatividade/FLEXIBLE DEFENSE SUCCEEDS CREATIVE ATTACKS - SIMULATION BASED ON POSITION DATA - Memmert, Imkamp e Perl (2021).pdf
mv	Documents/TCC/Referências/FOOTBALL - A CONSTRAINTS-LED APPROACH (PORTUGAL) - Ribeiro et al. (2025) (capítulo).pdf	Documents/1 TCC/Referências/Jogos reduzidos e restrições/FOOTBALL - A CONSTRAINTS-LED APPROACH (PORTUGAL) - Ribeiro et al. (2025) (capítulo).pdf
mv	Documents/TCC/Referências/FORMAR O TREINADOR E O JOGADOR NAS CATEGORIAS DE BASE DO FUTEBOL - Bettega et al. (2019).pdf	Documents/1 TCC/Referências/Dinâmica ecológica e ensino/FORMAR O TREINADOR E O JOGADOR NAS CATEGORIAS DE BASE DO FUTEBOL - Bettega et al. (2019).pdf
mv	Documents/TCC/Referências/FOUNDATIONS OF SMALL-SIDED GAMES - Clemente, Petiot e Coutinho (2025).pdf	Documents/1 TCC/Referências/Jogos reduzidos e restrições/FOUNDATIONS OF SMALL-SIDED GAMES - Clemente, Petiot e Coutinho (2025).pdf
mv	Documents/TCC/Referências/FUTEBOL E SEUS CONTEXTOS - Oliveira e Haiachi (2023) (livro).pdf	Documents/1 TCC/Referências/Dinâmica ecológica e ensino/FUTEBOL E SEUS CONTEXTOS - Oliveira e Haiachi (2023) (livro).pdf
mv	Documents/TCC/Referências/HOW DOES THE ADJUSTMENT OF TRAINING TASK DIFFICULTY LEVEL INFLUENCE TACTICAL BEHAVIOR IN SOCCER (2019).pdf	Documents/1 TCC/Referências/Jogos reduzidos e restrições/HOW DOES THE ADJUSTMENT OF TRAINING TASK DIFFICULTY LEVEL INFLUENCE TACTICAL BEHAVIOR IN SOCCER (2019).pdf
mv	Documents/TCC/Referências/IMPACT OF THE NUMBER OF PLAYERS ON CREATIVE MOVEMENTS IN SMALL-SIDED SOCCER GAMES - Ueda et al. (2023).pdf	Documents/1 TCC/Referências/Criatividade/IMPACT OF THE NUMBER OF PLAYERS ON CREATIVE MOVEMENTS IN SMALL-SIDED SOCCER GAMES - Ueda et al. (2023).pdf
mv	Documents/TCC/Referências/INCREASING UNCERTAINTY IMPROVES REPRESENTATIVE DESIGN OF PASSING PRACTICE TASKS - Travassos et al. (2012).pdf	Documents/1 TCC/Referências/Jogos reduzidos e restrições/INCREASING UNCERTAINTY IMPROVES REPRESENTATIVE DESIGN OF PASSING PRACTICE TASKS - Travassos et al. (2012).pdf
mv	Documents/TCC/Referências/INFLUENCE OF SCORING MODE AND AGE GROUP ON PASSING ACTIONS DURING SMALL-SIDED GAMES - Almeida et al. (2017).pdf	Documents/1 TCC/Referências/Jogos reduzidos e restrições/INFLUENCE OF SCORING MODE AND AGE GROUP ON PASSING ACTIONS DURING SMALL-SIDED GAMES - Almeida et al. (2017).pdf
mv	Documents/TCC/Referências/INFLUÊNCIA DO RESULTADO MOMENTÂNEO NA AMPLITUDE E PROFUNDIDADE DA CIRCULAÇÃO DA BOLA EM PEQUENOS JOGOS (2019).pdf	Documents/1 TCC/Referências/Jogos reduzidos e restrições/INFLUÊNCIA DO RESULTADO MOMENTÂNEO NA AMPLITUDE E PROFUNDIDADE DA CIRCULAÇÃO DA BOLA EM PEQUENOS JOGOS (2019).pdf
mv	Documents/TCC/Referências/JOGOS REDUZIDOS COMO HÓLONS NO FUTEBOL - ABORDAGEM SISTÊMICA HIERÁRQUICA - Reis (2021).pdf	Documents/1 TCC/Referências/Jogos reduzidos e restrições/JOGOS REDUZIDOS COMO HÓLONS NO FUTEBOL - ABORDAGEM SISTÊMICA HIERÁRQUICA - Reis (2021).pdf
mv	Documents/TCC/Referências/LONG-TERM PRACTICE WITH DOMAIN-SPECIFIC TASK CONSTRAINTS INFLUENCES PERCEPTUAL SKILLS - Oppici et al. (2017).pdf	Documents/1 TCC/Referências/Jogos reduzidos e restrições/LONG-TERM PRACTICE WITH DOMAIN-SPECIFIC TASK CONSTRAINTS INFLUENCES PERCEPTUAL SKILLS - Oppici et al. (2017).pdf
mv	Documents/TCC/Referências/O ENSINO DOS JOGOS ESPORTIVOS COLETIVOS - COMPETÊNCIAS ESSENCIAIS E LÓGICA DO JOGO - Scaglia et al. (2013).pdf	Documents/1 TCC/Referências/Dinâmica ecológica e ensino/O ENSINO DOS JOGOS ESPORTIVOS COLETIVOS - COMPETÊNCIAS ESSENCIAIS E LÓGICA DO JOGO - Scaglia et al. (2013).pdf
mv	Documents/TCC/Referências/O VALOR DA PRÁTICA COM E SEM OPOSIÇÃO - DINÂMICA ECOLÓGICA (2025) [PT].pdf	Documents/1 TCC/Referências/Dinâmica ecológica e ensino/O VALOR DA PRÁTICA COM E SEM OPOSIÇÃO - DINÂMICA ECOLÓGICA (2025) [PT].pdf
mv	Documents/TCC/Referências/PERCEPTUAL-COGNITIVE EXPERTISE IN SPORT - A META-ANALYSIS - Mann et al. (2007).pdf	Documents/1 TCC/Referências/Tomada de decisão e cognição/PERCEPTUAL-COGNITIVE EXPERTISE IN SPORT - A META-ANALYSIS - Mann et al. (2007).pdf
mv	Documents/TCC/Referências/RE-FRAMING PERFORMANCE ANALYSIS FROM AN ECOLOGICAL DYNAMICS PERSPECTIVE (2025).pdf	Documents/1 TCC/Referências/Dinâmica ecológica e ensino/RE-FRAMING PERFORMANCE ANALYSIS FROM AN ECOLOGICAL DYNAMICS PERSPECTIVE (2025).pdf
mv	Documents/TCC/Referências/SITUATION AWARENESS - SENSEMAKING AND DECISION MAKING IN PHYSICAL ACTIVITIES - Godbout (2023).pdf	Documents/1 TCC/Referências/Tomada de decisão e cognição/SITUATION AWARENESS - SENSEMAKING AND DECISION MAKING IN PHYSICAL ACTIVITIES - Godbout (2023).pdf
mv	Documents/TCC/Referências/SPORT PEDAGOGY IN PLAYED-FORM PRACTICE IN SOCCER - CONTENTS AND CONTEXTS (2024).pdf	Documents/1 TCC/Referências/Dinâmica ecológica e ensino/SPORT PEDAGOGY IN PLAYED-FORM PRACTICE IN SOCCER - CONTENTS AND CONTEXTS (2024).pdf
mv	Documents/TCC/Referências/TALENTO, CÉREBRO E DECISÃO NO FUTEBOL.pdf	Documents/1 TCC/Referências/Tomada de decisão e cognição/TALENTO, CÉREBRO E DECISÃO NO FUTEBOL.pdf
mv	Documents/TCC/Referências/TEAM SYNERGIES IN SPORT - THEORY AND MEASURES - Araújo e Davids (2016).pdf	Documents/1 TCC/Referências/Dinâmica ecológica e ensino/TEAM SYNERGIES IN SPORT - THEORY AND MEASURES - Araújo e Davids (2016).pdf
mv	Documents/TCC/Referências/THE CONTRIBUTION OF PERCEPTUAL AND COGNITIVE SKILLS IN ANTICIPATION PERFORMANCE - Casanova et al. (2014).pdf	Documents/1 TCC/Referências/Tomada de decisão e cognição/THE CONTRIBUTION OF PERCEPTUAL AND COGNITIVE SKILLS IN ANTICIPATION PERFORMANCE - Casanova et al. (2014).pdf
mv	Documents/TCC/Referências/THE ECOLOGICAL AND COGNITIVE APPROACHES TO DECISION MAKING IN FOOTBALL AND FUTSAL - RBFF (2021).pdf	Documents/1 TCC/Referências/Tomada de decisão e cognição/THE ECOLOGICAL AND COGNITIVE APPROACHES TO DECISION MAKING IN FOOTBALL AND FUTSAL - RBFF (2021).pdf
mv	Documents/TCC/Referências/THE ECOLOGICAL DYNAMICS OF COGNIZANT ACTION IN SPORT - Araújo et al. (2025).pdf	Documents/1 TCC/Referências/Tomada de decisão e cognição/THE ECOLOGICAL DYNAMICS OF COGNIZANT ACTION IN SPORT - Araújo et al. (2025).pdf
mv	Documents/TCC/Referências/THE KEY ROLE OF CONTEXT IN TEAM SPORTS TRAINING - THE VALUE OF PLAYED-FORM ACTIVITIES - Petiot et al. (2023).pdf	Documents/1 TCC/Referências/Dinâmica ecológica e ensino/THE KEY ROLE OF CONTEXT IN TEAM SPORTS TRAINING - THE VALUE OF PLAYED-FORM ACTIVITIES - Petiot et al. (2023).pdf
mv	Documents/TCC/Referências/WAYFINDING - ECOLOGICAL PERSPECTIVES OF NAVIGATING DYNAMIC ENVIRONMENTS - Woods et al. (2020).pdf	Documents/1 TCC/Referências/Dinâmica ecológica e ensino/WAYFINDING - ECOLOGICAL PERSPECTIVES OF NAVIGATING DYNAMIC ENVIRONMENTS - Woods et al. (2020).pdf
mv	Documents/TCC/Referências/WHAT TO LOOK FOR IN SETTING SPORTS TRAINING TASKS FOR YOUNG PLAYERS - NUMERICAL CONFIGURATION AND COURT SIZE (2023).pdf	Documents/1 TCC/Referências/Jogos reduzidos e restrições/WHAT TO LOOK FOR IN SETTING SPORTS TRAINING TASKS FOR YOUNG PLAYERS - NUMERICAL CONFIGURATION AND COURT SIZE (2023).pdf
mv	Documents/TCC/Referências/YOU'LL NEVER WALK ALONE - A COOPERAÇÃO COMO PARADIGMA DAS DINÂMICAS NO FUTEBOL (2013).pdf	Documents/1 TCC/Referências/Dinâmica ecológica e ensino/YOU'LL NEVER WALK ALONE - A COOPERAÇÃO COMO PARADIGMA DAS DINÂMICAS NO FUTEBOL (2013).pdf
rmdir	Documents/TCC/Referências	
mv	Documents/TCC/Arajo_et_al_2025 (1) (1).pdf	Documents/1 TCC/Escrita/Arajo_et_al_2025 (1) (1).pdf
mv	Documents/TCC/COGNIÇÃO RAAB E MARCOS REIS.pdf	Documents/1 TCC/Escrita/COGNIÇÃO RAAB E MARCOS REIS.pdf
mv	Documents/TCC/CRB	Documents/1 TCC/Coleta de Dados/CRB
mv	Documents/TCC/Copia de Termo de Aceite de Orientacao Voluntaria - TCC 2 assinado (1) (1) (1).pdf	Documents/1 TCC/Escrita/Copia de Termo de Aceite de Orientacao Voluntaria - TCC 2 assinado (1) (1) (1).pdf
mv	Documents/TCC/Copia de Termo de Aceite de Orientacao Voluntaria - TCC 2 assinado (1) (1) (2).pdf	Documents/1 TCC/Escrita/Copia de Termo de Aceite de Orientacao Voluntaria - TCC 2 assinado (1) (1) (2).pdf
mv	Documents/TCC/Copia de Termo de Aceite de Orientacao Voluntaria - TCC 2 assinado (1) (1).pdf	Documents/1 TCC/Escrita/Copia de Termo de Aceite de Orientacao Voluntaria - TCC 2 assinado (1) (1).pdf
mv	Documents/TCC/Copia de Termo de Aceite de Orientacao Voluntaria - TCC 2 assinado (1).pdf	Documents/1 TCC/Escrita/Copia de Termo de Aceite de Orientacao Voluntaria - TCC 2 assinado (1).pdf
mv	Documents/TCC/Corinthians - 31ago2020.pdf	Documents/1 TCC/Escrita/Corinthians - 31ago2020.pdf
mv	Documents/TCC/Criatividade TCC 1.pdf	Documents/1 TCC/Escrita/Criatividade TCC 1.pdf
mv	Documents/TCC/EXPLORATORY TACTICAL .en.pt (1).pdf	Documents/1 TCC/Escrita/EXPLORATORY TACTICAL .en.pt (1).pdf
mv	Documents/TCC/EXPLORATORY TACTICAL .pdf	Documents/1 TCC/Escrita/EXPLORATORY TACTICAL .pdf
mv	Documents/TCC/Expertise_and_perceptual-cognitive_performance_in_.pdf	Documents/1 TCC/Escrita/Expertise_and_perceptual-cognitive_performance_in_.pdf
mv	Documents/TCC/FICHAMENTO - RAAB (2003) - Gabriel Vitor (TCC II).pdf	Documents/1 TCC/Escrita/FICHAMENTO - RAAB (2003) - Gabriel Vitor (TCC II).pdf
mv	Documents/TCC/MARCOS REIS 1.pdf	Documents/1 TCC/Escrita/MARCOS REIS 1.pdf
mv	Documents/TCC/MODELO PROJETO DE PESQUISA.docx	Documents/1 TCC/Escrita/MODELO PROJETO DE PESQUISA.docx
mv	Documents/TCC/Michelini MarceloCompagno TCC.pdf	Documents/1 TCC/Escrita/Michelini MarceloCompagno TCC.pdf
mv	Documents/TCC/PROJETO DE PESQUISA GABRIEL.pdf	Documents/1 TCC/Escrita/PROJETO DE PESQUISA GABRIEL.pdf
mv	Documents/TCC/PROJETO TCC.docx	Documents/1 TCC/Escrita/PROJETO TCC.docx
mv	Documents/TCC/Parecer Orientador TCC Gabriel (1).pdf	Documents/1 TCC/Escrita/Parecer Orientador TCC Gabriel (1).pdf
mv	Documents/TCC/Parecer Orientador TCC Gabriel.pdf	Documents/1 TCC/Escrita/Parecer Orientador TCC Gabriel.pdf
mv	Documents/TCC/Plano de treino.pdf	Documents/1 TCC/Escrita/Plano de treino.pdf
mv	Documents/TCC/Preprojeto TCC1 Gabriel.docx	Documents/1 TCC/Escrita/Preprojeto TCC1 Gabriel.docx
mv	Documents/TCC/RESUMO ARTIGO TCC 1.pdf	Documents/1 TCC/Escrita/RESUMO ARTIGO TCC 1.pdf
mv	Documents/TCC/Relatório de Andamento do TCC.pdf	Documents/1 TCC/Escrita/Relatório de Andamento do TCC.pdf
mv	Documents/TCC/SINERGIAS GRUPAIS.pdf	Documents/1 TCC/Escrita/SINERGIAS GRUPAIS.pdf
mv	Documents/TCC/TCC - CRIATIVIDADE NO FUTEBOL - DIFERENCIAÇÃO DE METAS EM JOGOS REDUZIDOS - Gabriel Vitor (apresentação v2).pdf	Documents/1 TCC/Escrita/TCC - CRIATIVIDADE NO FUTEBOL - DIFERENCIAÇÃO DE METAS EM JOGOS REDUZIDOS - Gabriel Vitor (apresentação v2).pdf
mv	Documents/TCC/TCC - CRIATIVIDADE NO FUTEBOL - DIFERENCIAÇÃO DE METAS EM JOGOS REDUZIDOS - Gabriel Vitor (apresentação v3).pdf	Documents/1 TCC/Escrita/TCC - CRIATIVIDADE NO FUTEBOL - DIFERENCIAÇÃO DE METAS EM JOGOS REDUZIDOS - Gabriel Vitor (apresentação v3).pdf
mv	Documents/TCC/TCC - TERMO DE ACEITE DE ORIENTAÇÃO VOLUNTÁRIA (2026).pdf	Documents/1 TCC/Escrita/TCC - TERMO DE ACEITE DE ORIENTAÇÃO VOLUNTÁRIA (2026).pdf
mv	Documents/TCC/TCC - TOMADA DE DECISÃO CRIATIVA POR MEIO DO PASSE - Gabriel Vitor (apresentação v1).pdf	Documents/1 TCC/Escrita/TCC - TOMADA DE DECISÃO CRIATIVA POR MEIO DO PASSE - Gabriel Vitor (apresentação v1).pdf
mv	Documents/TCC/TCC CRB.mp4	Documents/1 TCC/Coleta de Dados/TCC CRB.mp4
mv	Documents/TCC/TCC1 GABRIEL.pdf	Documents/1 TCC/Escrita/TCC1 GABRIEL.pdf
mv	Documents/TCC/TREINAMENTO PERCEPTUAL-COGNITIVO.pdf	Documents/1 TCC/Escrita/TREINAMENTO PERCEPTUAL-COGNITIVO.pdf
mv	Documents/TCC/Termo de Aceite de Orientacao Voluntaria - TCC 2 assinado (1) 2.pdf	Documents/1 TCC/Escrita/Termo de Aceite de Orientacao Voluntaria - TCC 2 assinado (1) 2.pdf
mv	Documents/TCC/Termo de Aceite de Orientacao Voluntaria - TCC 2 assinado.docx	Documents/1 TCC/Escrita/Termo de Aceite de Orientacao Voluntaria - TCC 2 assinado.docx
mv	Documents/TCC/The effect of nonlinear pedagogy on the acquisition of game skills in a territorial game.pdf	Documents/1 TCC/Escrita/The effect of nonlinear pedagogy on the acquisition of game skills in a territorial game.pdf
mv	Documents/TCC/The_key_role_of_context_in_team_sports_training_Th pt-BR.pdf	Documents/1 TCC/Escrita/The_key_role_of_context_in_team_sports_training_Th pt-BR.pdf
mv	Documents/TCC/The_key_role_of_context_in_team_sports_training_Th.pdf	Documents/1 TCC/Escrita/The_key_role_of_context_in_team_sports_training_Th.pdf
mv	Documents/TCC/raab_2003_IJSP_ILELcomplexity (1).pdf	Documents/1 TCC/Escrita/raab_2003_IJSP_ILELcomplexity (1).pdf
mv	Documents/TCC/raab_2003_IJSP_ILELcomplexity.pdf	Documents/1 TCC/Escrita/raab_2003_IJSP_ILELcomplexity.pdf
mv	Documents/TCC/scaglia alcidesjose 2 tcc.pdf	Documents/1 TCC/Escrita/scaglia alcidesjose 2 tcc.pdf
rmdir	Documents/TCC	
mv	Documents/América-PE/Adversários/Geral/Analise Adversario - PNG	Documents/2 América-PE/A definir/Adversários/Analise Adversario - PNG
mv	Documents/América-PE/Adversários/Geral/Analise Adversario - PNG 2	Documents/2 América-PE/A definir/Adversários/Analise Adversario - PNG 2
mv	Documents/América-PE/Adversários/Geral/Analise Adversario - Slide 9.pptx	Documents/2 América-PE/A definir/Adversários/Analise Adversario - Slide 9.pptx
mv	Documents/América-PE/Adversários/Geral/Análise adversário	Documents/2 América-PE/A definir/Adversários/Análise adversário
mv	Documents/América-PE/Adversários/Geral/Análise adversário.pdf	Documents/2 América-PE/Sub-20/Adversários/Análise adversário.pdf
mv	Documents/América-PE/Adversários/Geral/Análise adversário.zip	Documents/2 América-PE/A definir/Adversários/Análise adversário.zip
mv	Documents/América-PE/Adversários/Geral/Cópia de Análise adversário (1).mp4	Documents/2 América-PE/A definir/Adversários/Cópia de Análise adversário (1).mp4
mv	Documents/América-PE/Adversários/Geral/Cópia de Análise adversário (2).pdf	Documents/2 América-PE/A definir/Adversários/Cópia de Análise adversário (2).pdf
mv	Documents/América-PE/Adversários/Geral/Cópia de Análise adversário (3).pdf	Documents/2 América-PE/A definir/Adversários/Cópia de Análise adversário (3).pdf
mv	Documents/América-PE/Adversários/Geral/Cópia de Análise adversário (4).pdf	Documents/2 América-PE/A definir/Adversários/Cópia de Análise adversário (4).pdf
mv	Documents/América-PE/Adversários/Geral/Cópia de Análise adversário (5).pdf	Documents/2 América-PE/A definir/Adversários/Cópia de Análise adversário (5).pdf
mv	Documents/América-PE/Adversários/Geral/Cópia de Análise adversário.mp4	Documents/2 América-PE/A definir/Adversários/Cópia de Análise adversário.mp4
mv	Documents/América-PE/Adversários/Geral/Cópia de Análise adversário.pdf	Documents/2 América-PE/Sub-20/Adversários/Cópia de Análise adversário.pdf
rmdir	Documents/América-PE/Adversários/Geral	
mv	Documents/América-PE/Adversários/Náutico/2 gol nautico.mov	Documents/2 América-PE/Sub-20/Adversários/Náutico/2 gol nautico.mov
mv	Documents/América-PE/Adversários/Náutico/BOLAS PARADAS COMPILADO NAÚTICO.mov	Documents/2 América-PE/Sub-20/Adversários/Náutico/BOLAS PARADAS COMPILADO NAÚTICO.mov
mv	Documents/América-PE/Adversários/Náutico/bola parada nautico 1.mov	Documents/2 América-PE/Sub-20/Adversários/Náutico/bola parada nautico 1.mov
mv	Documents/América-PE/Adversários/Náutico/bola parada nautico 2.mov	Documents/2 América-PE/Sub-20/Adversários/Náutico/bola parada nautico 2.mov
mv	Documents/América-PE/Adversários/Náutico/bola parada nautico 3.mov	Documents/2 América-PE/Sub-20/Adversários/Náutico/bola parada nautico 3.mov
mv	Documents/América-PE/Adversários/Náutico/bolas paradas nautico 2.mov	Documents/2 América-PE/Sub-20/Adversários/Náutico/bolas paradas nautico 2.mov
rmdir	Documents/América-PE/Adversários/Náutico	
mv	Documents/América-PE/Adversários/Retrô/Analise Retro Sub20 - PNG	Documents/2 América-PE/Sub-20/Adversários/Retrô/Analise Retro Sub20 - PNG
mv	Documents/América-PE/Adversários/Retrô/Analise Retro Sub20 - PNG 2	Documents/2 América-PE/Sub-20/Adversários/Retrô/Analise Retro Sub20 - PNG 2
mv	Documents/América-PE/Adversários/Retrô/BOLAS PARADAS RETRO 2.mov	Documents/2 América-PE/Sub-20/Adversários/Retrô/BOLAS PARADAS RETRO 2.mov
mv	Documents/América-PE/Adversários/Retrô/BOLAS PARADAS RETRO.mov	Documents/2 América-PE/Sub-20/Adversários/Retrô/BOLAS PARADAS RETRO.mov
mv	Documents/América-PE/Adversários/Retrô/PRESSÃO RETRO 2.mov	Documents/2 América-PE/Sub-20/Adversários/Retrô/PRESSÃO RETRO 2.mov
mv	Documents/América-PE/Adversários/Retrô/PRESSÃO RETRO.mov	Documents/2 América-PE/Sub-20/Adversários/Retrô/PRESSÃO RETRO.mov
mv	Documents/América-PE/Adversários/Retrô/RETRO C BOLA 2.mov	Documents/2 América-PE/Sub-20/Adversários/Retrô/RETRO C BOLA 2.mov
mv	Documents/América-PE/Adversários/Retrô/RETRO C BOLA.mov	Documents/2 América-PE/Sub-20/Adversários/Retrô/RETRO C BOLA.mov
rmdir	Documents/América-PE/Adversários/Retrô	
mv	Documents/América-PE/Adversários/Sport/Bola parada sport 1.mov	Documents/2 América-PE/Sub-20/Adversários/Sport/Bola parada sport 1.mov
mv	Documents/América-PE/Adversários/Sport/bola parada sport 2.mov	Documents/2 América-PE/Sub-20/Adversários/Sport/bola parada sport 2.mov
rmdir	Documents/América-PE/Adversários/Sport	
mv	Documents/América-PE/Adversários/Treze/ANÁLISE TREZE.mp4	Documents/2 América-PE/Profissional/Adversários/Treze/ANÁLISE TREZE.mp4
mv	Documents/América-PE/Adversários/Treze/Analise Treze - PNG	Documents/2 América-PE/Profissional/Adversários/Treze/Analise Treze - PNG
mv	Documents/América-PE/Adversários/Treze/BOLAS PARADAS TREZE.MOV	Documents/2 América-PE/Profissional/Adversários/Treze/BOLAS PARADAS TREZE.MOV
mv	Documents/América-PE/Adversários/Treze/ORG. DEFENSIVA TREZE.MOV	Documents/2 América-PE/Profissional/Adversários/Treze/ORG. DEFENSIVA TREZE.MOV
mv	Documents/América-PE/Adversários/Treze/ORG. OFENSIVA TREZE.MOV	Documents/2 América-PE/Profissional/Adversários/Treze/ORG. OFENSIVA TREZE.MOV
rmdir	Documents/América-PE/Adversários/Treze	
rmdir	Documents/América-PE/Adversários	
mv	Documents/América-PE/Capturas de Tela/Captura de Tela 2026-10-02 às 10.29.20.png	Documents/2 América-PE/A definir/Jogos e Cortes/Captura de Tela 2026-10-02 às 10.29.20.png
rmdir	Documents/América-PE/Capturas de Tela	
mv	Documents/América-PE/Cortes de Vídeo/!.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/!.mov
mv	Documents/América-PE/Cortes de Vídeo/1 trave menor estatura.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/1 trave menor estatura.mov
mv	Documents/América-PE/Cortes de Vídeo/1as bolas.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/1as bolas.mov
mv	Documents/América-PE/Cortes de Vídeo/1ª pressão.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/1ª pressão.mov
mv	Documents/América-PE/Cortes de Vídeo/3º Homem para progressão.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/3º Homem para progressão.mov
mv	Documents/América-PE/Cortes de Vídeo/9 jogar em apoio.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/9 jogar em apoio.mov
mv	Documents/América-PE/Cortes de Vídeo/Abordagem defensiva aleatória.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/Abordagem defensiva aleatória.mov
mv	Documents/América-PE/Cortes de Vídeo/Acompanhamento pelos pontas nao ocorre bem.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/Acompanhamento pelos pontas nao ocorre bem.mov
mv	Documents/América-PE/Cortes de Vídeo/Aproveitar amplitude!.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/Aproveitar amplitude!.mov
mv	Documents/América-PE/Cortes de Vídeo/Atacar espaço!.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/Atacar espaço!.mov
mv	Documents/América-PE/Cortes de Vídeo/Atraso dos encaixes.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/Atraso dos encaixes.mov
mv	Documents/América-PE/Cortes de Vídeo/BOLA DE 2 TRAVE.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/BOLA DE 2 TRAVE.mov
mv	Documents/América-PE/Cortes de Vídeo/BOLA PARADA 22.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/BOLA PARADA 22.mov
mv	Documents/América-PE/Cortes de Vídeo/BOLA PARADA 23.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/BOLA PARADA 23.mov
mv	Documents/América-PE/Cortes de Vídeo/BOLA PARADA 25.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/BOLA PARADA 25.mov
mv	Documents/América-PE/Cortes de Vídeo/BOLA PARADA 27.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/BOLA PARADA 27.mov
mv	Documents/América-PE/Cortes de Vídeo/BOLA PARADA 29.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/BOLA PARADA 29.mov
mv	Documents/América-PE/Cortes de Vídeo/BOLA PARADA 4.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/BOLA PARADA 4.mov
mv	Documents/América-PE/Cortes de Vídeo/BOLAS PARADAS VITÓRIA.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/BOLAS PARADAS VITÓRIA.mov
mv	Documents/América-PE/Cortes de Vídeo/Bola de primeira trave muita responsabilidade do goleiro( explorar).mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/Bola de primeira trave muita responsabilidade do goleiro( explorar).mov
mv	Documents/América-PE/Cortes de Vídeo/Bola descoberta!.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/Bola descoberta!.mov
mv	Documents/América-PE/Cortes de Vídeo/Bola descoberta.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/Bola descoberta.mov
mv	Documents/América-PE/Cortes de Vídeo/Bola parada ofensiva 2.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/Bola parada ofensiva 2.mov
mv	Documents/América-PE/Cortes de Vídeo/Bola parada ofensiva.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/Bola parada ofensiva.mov
mv	Documents/América-PE/Cortes de Vídeo/Bolas de circulação + ruptura confundem a marcação.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/Bolas de circulação + ruptura confundem a marcação.mov
mv	Documents/América-PE/Cortes de Vídeo/Bom preenchimento da área.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/Bom preenchimento da área.mov
mv	Documents/América-PE/Cortes de Vídeo/Bom preenchimento de área, x1 e apoio do 9.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/Bom preenchimento de área, x1 e apoio do 9.mov
mv	Documents/América-PE/Cortes de Vídeo/Bom preenchimento de área.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/Bom preenchimento de área.mov
mv	Documents/América-PE/Cortes de Vídeo/Bons movimentos com bola, ser variável pé e espaço.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/Bons movimentos com bola, ser variável pé e espaço.mov
mv	Documents/América-PE/Cortes de Vídeo/Circulação para as vantagens.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/Circulação para as vantagens.mov
mv	Documents/América-PE/Cortes de Vídeo/Cobrir passes por dentro.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/Cobrir passes por dentro.mov
mv	Documents/América-PE/Cortes de Vídeo/Conexão lateral ponta.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/Conexão lateral ponta.mov
mv	Documents/América-PE/Cortes de Vídeo/Construc por dentro e uso do 9.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/Construc por dentro e uso do 9.mov
mv	Documents/América-PE/Cortes de Vídeo/Construção por dentro dificultosa.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/Construção por dentro dificultosa.mov
mv	Documents/América-PE/Cortes de Vídeo/Construção por dentro, fazer bola descoberta no volante de arrasto.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/Construção por dentro, fazer bola descoberta no volante de arrasto.mov
mv	Documents/América-PE/Cortes de Vídeo/Construção z1.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/Construção z1.mov
mv	Documents/América-PE/Cortes de Vídeo/Corredor central deve haver pressão!.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/Corredor central deve haver pressão!.mov
mv	Documents/América-PE/Cortes de Vídeo/Defendendo bola parada.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/Defendendo bola parada.mov
mv	Documents/América-PE/Cortes de Vídeo/Defender em 541.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/Defender em 541.mov
mv	Documents/América-PE/Cortes de Vídeo/Defesa do corredor central.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/Defesa do corredor central.mov
mv	Documents/América-PE/Cortes de Vídeo/Dentro para achar por fora.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/Dentro para achar por fora.mov
mv	Documents/América-PE/Cortes de Vídeo/Dentro, ter aproximação!.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/Dentro, ter aproximação!.mov
mv	Documents/América-PE/Cortes de Vídeo/Descompactação da linha de 4.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/Descompactação da linha de 4.mov
mv	Documents/América-PE/Cortes de Vídeo/Desestruturação da linha de 4.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/Desestruturação da linha de 4.mov
mv	Documents/América-PE/Cortes de Vídeo/Desorganização numérica não pode existir.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/Desorganização numérica não pode existir.mov
mv	Documents/América-PE/Cortes de Vídeo/Dificuldade em jogar dos zagueiros.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/Dificuldade em jogar dos zagueiros.mov
mv	Documents/América-PE/Cortes de Vídeo/Dinâmicas de progressão.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/Dinâmicas de progressão.mov
mv	Documents/América-PE/Cortes de Vídeo/Entrelinhas para achar por fora.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/Entrelinhas para achar por fora.mov
mv	Documents/América-PE/Cortes de Vídeo/Entrelinhas!!.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/Entrelinhas!!.mov
mv	Documents/América-PE/Cortes de Vídeo/Esconder intenção, nas janelas já receber para a profundidade.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/Esconder intenção, nas janelas já receber para a profundidade.mov
mv	Documents/América-PE/Cortes de Vídeo/Falta de linhas de passe de progressão.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/Falta de linhas de passe de progressão.mov
mv	Documents/América-PE/Cortes de Vídeo/Fechar progressão por dentro!.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/Fechar progressão por dentro!.mov
mv	Documents/América-PE/Cortes de Vídeo/Gatilhos defensivos.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/Gatilhos defensivos.mov
mv	Documents/América-PE/Cortes de Vídeo/Gol sofrido vitória.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/Gol sofrido vitória.mov
mv	Documents/América-PE/Cortes de Vídeo/Igualam na zona de pressão, lateral que salta.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/Igualam na zona de pressão, lateral que salta.mov
mv	Documents/América-PE/Cortes de Vídeo/Importancia da estrtura na transição defensiva!.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/Importancia da estrtura na transição defensiva!.mov
mv	Documents/América-PE/Cortes de Vídeo/Importancia de pesar lado da bola.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/Importancia de pesar lado da bola.mov
mv	Documents/América-PE/Cortes de Vídeo/Importancia de verticalizar.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/Importancia de verticalizar.mov
mv	Documents/América-PE/Cortes de Vídeo/Importância de estar próximo, importância da mobilidade na 1ª construção.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/Importância de estar próximo, importância da mobilidade na 1ª construção.mov
mv	Documents/América-PE/Cortes de Vídeo/Importância dos apoios, mexer nas linhas adversárias.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/Importância dos apoios, mexer nas linhas adversárias.mov
mv	Documents/América-PE/Cortes de Vídeo/Importância dos movimentos de engano!.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/Importância dos movimentos de engano!.mov
mv	Documents/América-PE/Cortes de Vídeo/Jogar dentro para ter espaço por fora- dinamica de 3 homem.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/Jogar dentro para ter espaço por fora- dinamica de 3 homem.mov
mv	Documents/América-PE/Cortes de Vídeo/Jogo interior de parede vai ter espaço para ocorrer, CRITÉRIO.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/Jogo interior de parede vai ter espaço para ocorrer, CRITÉRIO.mov
mv	Documents/América-PE/Cortes de Vídeo/Jogo interior e verticalizar!.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/Jogo interior e verticalizar!.mov
mv	Documents/América-PE/Cortes de Vídeo/Kleber 2.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/Kleber 2.mov
mv	Documents/América-PE/Cortes de Vídeo/Kleber.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/Kleber.mov
mv	Documents/América-PE/Cortes de Vídeo/Lado oposoto com tempo e espaço.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/Lado oposoto com tempo e espaço.mov
mv	Documents/América-PE/Cortes de Vídeo/Linhas de passe engessadas.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/Linhas de passe engessadas.mov
mv	Documents/América-PE/Cortes de Vídeo/Longa confiando em falhas.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/Longa confiando em falhas.mov
mv	Documents/América-PE/Cortes de Vídeo/Meias buscando ruptura.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/Meias buscando ruptura.mov
mv	Documents/América-PE/Cortes de Vídeo/Mesmo fechando dentro, consegue interceptar passe.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/Mesmo fechando dentro, consegue interceptar passe.mov
mv	Documents/América-PE/Cortes de Vídeo/Mobilidade nas construções, importância de reinicio para contramovimento.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/Mobilidade nas construções, importância de reinicio para contramovimento.mov
mv	Documents/América-PE/Cortes de Vídeo/Mobilidade nas construções.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/Mobilidade nas construções.mov
mv	Documents/América-PE/Cortes de Vídeo/Mudança do lado da bola.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/Mudança do lado da bola.mov
mv	Documents/América-PE/Cortes de Vídeo/Não permitir circulações por dentro....mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/Não permitir circulações por dentro....mov
mv	Documents/América-PE/Cortes de Vídeo/POSICIONAM.DIAGONAIS.mov	Documents/2 América-PE/A definir/Jogos e Cortes/POSICIONAM.DIAGONAIS.mov
mv	Documents/América-PE/Cortes de Vídeo/PREENCH ÁREA.mov	Documents/2 América-PE/A definir/Jogos e Cortes/PREENCH ÁREA.mov
mv	Documents/América-PE/Cortes de Vídeo/Preencher área.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/Preencher área.mov
mv	Documents/América-PE/Cortes de Vídeo/Pressionados por dentro dificuldade para jogar.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/Pressionados por dentro dificuldade para jogar.mov
mv	Documents/América-PE/Cortes de Vídeo/Pressão + passe para trás!.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/Pressão + passe para trás!.mov
mv	Documents/América-PE/Cortes de Vídeo/Prontidão nos reincios e manutenção das distâncias na linha de 4.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/Prontidão nos reincios e manutenção das distâncias na linha de 4.mov
mv	Documents/América-PE/Cortes de Vídeo/Protagonismo dos zagueiros, aproveitamento do meio espaço para progressão!.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/Protagonismo dos zagueiros, aproveitamento do meio espaço para progressão!.mov
mv	Documents/América-PE/Cortes de Vídeo/Proteger a profundidade 2.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/Proteger a profundidade 2.mov
mv	Documents/América-PE/Cortes de Vídeo/Proteger a profundidade.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/Proteger a profundidade.mov
mv	Documents/América-PE/Cortes de Vídeo/RUPTURAS! EXPOSTOS A ISSO.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/RUPTURAS! EXPOSTOS A ISSO.mov
mv	Documents/América-PE/Cortes de Vídeo/Recebe no entrelinhas de maneira menos confortável.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/Recebe no entrelinhas de maneira menos confortável.mov
mv	Documents/América-PE/Cortes de Vídeo/Se houver compactacão nao sofre.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/Se houver compactacão nao sofre.mov
mv	Documents/América-PE/Cortes de Vídeo/Sem Título.mov	Documents/2 América-PE/A definir/Jogos e Cortes/Sem Título.mov
mv	Documents/América-PE/Cortes de Vídeo/Ter soluções por fora também.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/Ter soluções por fora também.mov
mv	Documents/América-PE/Cortes de Vídeo/Ter um 9 móvel vai ser bom.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/Ter um 9 móvel vai ser bom.mov
mv	Documents/América-PE/Cortes de Vídeo/Transitam defensivamente com poucos!.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/Transitam defensivamente com poucos!.mov
mv	Documents/América-PE/Cortes de Vídeo/ULTRAPASSAGEM POR DENTRO!.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/ULTRAPASSAGEM POR DENTRO!.mov
mv	Documents/América-PE/Cortes de Vídeo/Ultrapassagens por dentro.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/Ultrapassagens por dentro.mov
mv	Documents/América-PE/Cortes de Vídeo/Utilização da amplitude pelo lateral!.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/Utilização da amplitude pelo lateral!.mov
mv	Documents/América-PE/Cortes de Vídeo/apoio e ruptura.mov	Documents/2 América-PE/A definir/Jogos e Cortes/apoio e ruptura.mov
mv	Documents/América-PE/Cortes de Vídeo/aproveitar vantagens....mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/aproveitar vantagens....mov
mv	Documents/América-PE/Cortes de Vídeo/aproveitar vantagens.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/aproveitar vantagens.mov
mv	Documents/América-PE/Cortes de Vídeo/atacar espaço! bom.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/atacar espaço! bom.mov
mv	Documents/América-PE/Cortes de Vídeo/bola de 2 trave!.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/bola de 2 trave!.mov
mv	Documents/América-PE/Cortes de Vídeo/bola parada 1.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/bola parada 1.mov
mv	Documents/América-PE/Cortes de Vídeo/bola parada 3.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/bola parada 3.mov
mv	Documents/América-PE/Cortes de Vídeo/bola parada defensiva 2.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/bola parada defensiva 2.mov
mv	Documents/América-PE/Cortes de Vídeo/bom uso de dentro.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/bom uso de dentro.mov
mv	Documents/América-PE/Cortes de Vídeo/circular.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/circular.mov
mv	Documents/América-PE/Cortes de Vídeo/cobertura defensiva volante.mov	Documents/2 América-PE/A definir/Jogos e Cortes/cobertura defensiva volante.mov
mv	Documents/América-PE/Cortes de Vídeo/coberturas de meio no confronto com ponta.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/coberturas de meio no confronto com ponta.mov
mv	Documents/América-PE/Cortes de Vídeo/construir com 2 volantes.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/construir com 2 volantes.mov
mv	Documents/América-PE/Cortes de Vídeo/defesa bola oposta.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/defesa bola oposta.mov
mv	Documents/América-PE/Cortes de Vídeo/deixam espaços no entrelinhas.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/deixam espaços no entrelinhas.mov
mv	Documents/América-PE/Cortes de Vídeo/desprot. área.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/desprot. área.mov
mv	Documents/América-PE/Cortes de Vídeo/eliseu.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/eliseu.mov
mv	Documents/América-PE/Cortes de Vídeo/fechar dentro.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/fechar dentro.mov
mv	Documents/América-PE/Cortes de Vídeo/fechou por dentro.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/fechou por dentro.mov
mv	Documents/América-PE/Cortes de Vídeo/ganhar profundidades, portagonismo aos zagueiros.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/ganhar profundidades, portagonismo aos zagueiros.mov
mv	Documents/América-PE/Cortes de Vídeo/gol sofrido.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/gol sofrido.mov
mv	Documents/América-PE/Cortes de Vídeo/lateral encaixotado pressionar.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/lateral encaixotado pressionar.mov
mv	Documents/América-PE/Cortes de Vídeo/lateral passe p trás.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/lateral passe p trás.mov
mv	Documents/América-PE/Cortes de Vídeo/marcação quando é 3.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/marcação quando é 3.mov
mv	Documents/América-PE/Cortes de Vídeo/meia rompendo + passe para trás( transição defensiva!).mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/meia rompendo + passe para trás( transição defensiva!).mov
mv	Documents/América-PE/Cortes de Vídeo/mob construc- 3+1-extremo 1x1-preench.área.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/mob construc- 3+1-extremo 1x1-preench.área.mov
mv	Documents/América-PE/Cortes de Vídeo/não precisa ir participar da construção ai.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/não precisa ir participar da construção ai.mov
mv	Documents/América-PE/Cortes de Vídeo/paciencia no ulti. terço- preenchimento de área.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/paciencia no ulti. terço- preenchimento de área.mov
mv	Documents/América-PE/Cortes de Vídeo/paciencia p circular.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/paciencia p circular.mov
mv	Documents/América-PE/Cortes de Vídeo/paciencia para circulação.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/paciencia para circulação.mov
mv	Documents/América-PE/Cortes de Vídeo/pressao no lateral 2.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/pressao no lateral 2.mov
mv	Documents/América-PE/Cortes de Vídeo/principio defensivo 2.mov	Documents/2 América-PE/A definir/Jogos e Cortes/principio defensivo 2.mov
mv	Documents/América-PE/Cortes de Vídeo/principio ofensivo 1.mov	Documents/2 América-PE/A definir/Jogos e Cortes/principio ofensivo 1.mov
mv	Documents/América-PE/Cortes de Vídeo/principio ofensivo 2.mov	Documents/2 América-PE/A definir/Jogos e Cortes/principio ofensivo 2.mov
mv	Documents/América-PE/Cortes de Vídeo/profundidade!!!.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/profundidade!!!.mov
mv	Documents/América-PE/Cortes de Vídeo/recompactação linha de 3.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/recompactação linha de 3.mov
mv	Documents/América-PE/Cortes de Vídeo/salto ariel, cleber e vinicius.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/salto ariel, cleber e vinicius.mov
mv	Documents/América-PE/Cortes de Vídeo/tempo e espaço p construir.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/tempo e espaço p construir.mov
mv	Documents/América-PE/Cortes de Vídeo/teste.mov	Documents/2 América-PE/A definir/Jogos e Cortes/teste.mov
mv	Documents/América-PE/Cortes de Vídeo/trajetorias em diagonais.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/trajetorias em diagonais.mov
mv	Documents/América-PE/Cortes de Vídeo/transição?.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/transição?.mov
mv	Documents/América-PE/Cortes de Vídeo/ultimo terço.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/ultimo terço.mov
mv	Documents/América-PE/Cortes de Vídeo/ultrapassagem por dentro.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/ultrapassagem por dentro.mov
mv	Documents/América-PE/Cortes de Vídeo/usarndo janelas-protagonismo aos zagueiros.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/usarndo janelas-protagonismo aos zagueiros.mov
mv	Documents/América-PE/Cortes de Vídeo/veticalizar 2.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/veticalizar 2.mov
mv	Documents/América-PE/Cortes de Vídeo/zagueiros fechar dentro, fechar entrelinhas.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/zagueiros fechar dentro, fechar entrelinhas.mov
rmdir	Documents/América-PE/Cortes de Vídeo	
mv	Documents/América-PE/FLUXOGRAMA DE PROCESSOS - ANÁLISE DE DESEMPENHO (2026).pdf	Documents/2 América-PE/Clube/FLUXOGRAMA DE PROCESSOS - ANÁLISE DE DESEMPENHO (2026).pdf
mv	Documents/América-PE/Gravações de Tela/Gravação de Tela 2026-09-29 às 10.20.19.mov	Documents/2 América-PE/A definir/Jogos e Cortes/Gravação de Tela 2026-09-29 às 10.20.19.mov
mv	Documents/América-PE/Gravações de Tela/Gravação de Tela 2026-10-03 às 21.38.43.mov	Documents/2 América-PE/Profissional/Jogos e Cortes/Gravação de Tela 2026-10-03 às 21.38.43.mov
mv	Documents/América-PE/Gravações de Tela/Gravação de Tela 2026-10-03 às 21.43.19.mov	Documents/2 América-PE/Profissional/Jogos e Cortes/Gravação de Tela 2026-10-03 às 21.43.19.mov
mv	Documents/América-PE/Gravações de Tela/Gravação de Tela 2026-10-03 às 21.48.41.mov	Documents/2 América-PE/Profissional/Jogos e Cortes/Gravação de Tela 2026-10-03 às 21.48.41.mov
mv	Documents/América-PE/Gravações de Tela/Gravação de Tela 2026-10-03 às 21.51.13.mov	Documents/2 América-PE/Profissional/Jogos e Cortes/Gravação de Tela 2026-10-03 às 21.51.13.mov
mv	Documents/América-PE/Gravações de Tela/Gravação de Tela 2026-10-03 às 21.52.49.mov	Documents/2 América-PE/Profissional/Jogos e Cortes/Gravação de Tela 2026-10-03 às 21.52.49.mov
mv	Documents/América-PE/Gravações de Tela/Gravação de Tela 2026-10-03 às 21.55.51.mov	Documents/2 América-PE/Profissional/Jogos e Cortes/Gravação de Tela 2026-10-03 às 21.55.51.mov
mv	Documents/América-PE/Gravações de Tela/Gravação de Tela 2026-10-03 às 21.59.00.mov	Documents/2 América-PE/Profissional/Jogos e Cortes/Gravação de Tela 2026-10-03 às 21.59.00.mov
mv	Documents/América-PE/Gravações de Tela/Gravação de Tela 2026-10-03 às 22.00.06.mov	Documents/2 América-PE/Profissional/Jogos e Cortes/Gravação de Tela 2026-10-03 às 22.00.06.mov
mv	Documents/América-PE/Gravações de Tela/Gravação de Tela 2026-10-03 às 22.00.43.mov	Documents/2 América-PE/Profissional/Jogos e Cortes/Gravação de Tela 2026-10-03 às 22.00.43.mov
mv	Documents/América-PE/Gravações de Tela/Gravação de Tela 2026-10-03 às 22.01.49.mov	Documents/2 América-PE/Profissional/Jogos e Cortes/Gravação de Tela 2026-10-03 às 22.01.49.mov
mv	Documents/América-PE/Gravações de Tela/Gravação de Tela 2026-10-03 às 22.02.59.mov	Documents/2 América-PE/Profissional/Jogos e Cortes/Gravação de Tela 2026-10-03 às 22.02.59.mov
mv	Documents/América-PE/Gravações de Tela/Gravação de Tela 2026-10-03 às 22.05.05.mov	Documents/2 América-PE/Profissional/Jogos e Cortes/Gravação de Tela 2026-10-03 às 22.05.05.mov
mv	Documents/América-PE/Gravações de Tela/Gravação de Tela 2026-10-03 às 22.10.04.mov	Documents/2 América-PE/Profissional/Jogos e Cortes/Gravação de Tela 2026-10-03 às 22.10.04.mov
mv	Documents/América-PE/Gravações de Tela/Gravação de Tela 2026-10-03 às 22.13.20.mov	Documents/2 América-PE/Profissional/Jogos e Cortes/Gravação de Tela 2026-10-03 às 22.13.20.mov
mv	Documents/América-PE/Gravações de Tela/Gravação de Tela 2026-10-03 às 22.16.10.mov	Documents/2 América-PE/Profissional/Jogos e Cortes/Gravação de Tela 2026-10-03 às 22.16.10.mov
mv	Documents/América-PE/Gravações de Tela/Gravação de Tela 2026-10-03 às 22.18.46.mov	Documents/2 América-PE/Profissional/Jogos e Cortes/Gravação de Tela 2026-10-03 às 22.18.46.mov
mv	Documents/América-PE/Gravações de Tela/Gravação de Tela 2026-10-03 às 22.24.49.mov	Documents/2 América-PE/Profissional/Jogos e Cortes/Gravação de Tela 2026-10-03 às 22.24.49.mov
mv	Documents/América-PE/Gravações de Tela/Gravação de Tela 2026-10-03 às 22.26.22.mov	Documents/2 América-PE/Profissional/Jogos e Cortes/Gravação de Tela 2026-10-03 às 22.26.22.mov
mv	Documents/América-PE/Gravações de Tela/Gravação de Tela 2026-10-06 às 09.36.02.mov	Documents/2 América-PE/A definir/Jogos e Cortes/Gravação de Tela 2026-10-06 às 09.36.02.mov
mv	Documents/América-PE/Gravações de Tela/Gravação de Tela 2026-10-06 às 09.40.14.mov	Documents/2 América-PE/A definir/Jogos e Cortes/Gravação de Tela 2026-10-06 às 09.40.14.mov
mv	Documents/América-PE/Gravações de Tela/Gravação de Tela 2026-10-06 às 09.41.47.mov	Documents/2 América-PE/A definir/Jogos e Cortes/Gravação de Tela 2026-10-06 às 09.41.47.mov
mv	Documents/América-PE/Gravações de Tela/Gravação de Tela 2026-10-06 às 09.47.05.mov	Documents/2 América-PE/A definir/Jogos e Cortes/Gravação de Tela 2026-10-06 às 09.47.05.mov
mv	Documents/América-PE/Gravações de Tela/Gravação de Tela 2026-10-06 às 09.51.03.mov	Documents/2 América-PE/A definir/Jogos e Cortes/Gravação de Tela 2026-10-06 às 09.51.03.mov
mv	Documents/América-PE/Gravações de Tela/Gravação de Tela 2026-10-06 às 09.52.11.mov	Documents/2 América-PE/A definir/Jogos e Cortes/Gravação de Tela 2026-10-06 às 09.52.11.mov
mv	Documents/América-PE/Gravações de Tela/Gravação de Tela 2026-10-06 às 09.53.21.mov	Documents/2 América-PE/A definir/Jogos e Cortes/Gravação de Tela 2026-10-06 às 09.53.21.mov
mv	Documents/América-PE/Gravações de Tela/Gravação de Tela 2026-10-06 às 09.58.06.mov	Documents/2 América-PE/A definir/Jogos e Cortes/Gravação de Tela 2026-10-06 às 09.58.06.mov
mv	Documents/América-PE/Gravações de Tela/Gravação de Tela 2026-10-06 às 10.02.31.mov	Documents/2 América-PE/A definir/Jogos e Cortes/Gravação de Tela 2026-10-06 às 10.02.31.mov
mv	Documents/América-PE/Gravações de Tela/Gravação de Tela 2026-10-06 às 10.02.43.mov	Documents/2 América-PE/A definir/Jogos e Cortes/Gravação de Tela 2026-10-06 às 10.02.43.mov
mv	Documents/América-PE/Gravações de Tela/Gravação de Tela 2026-10-06 às 10.07.01.mov	Documents/2 América-PE/A definir/Jogos e Cortes/Gravação de Tela 2026-10-06 às 10.07.01.mov
mv	Documents/América-PE/Gravações de Tela/Gravação de Tela 2026-10-06 às 10.14.57.mov	Documents/2 América-PE/A definir/Jogos e Cortes/Gravação de Tela 2026-10-06 às 10.14.57.mov
rmdir	Documents/América-PE/Gravações de Tela	
mv	Documents/América-PE/Jogos/1 TEMPO AMISTOSO AMERICA X SANTA FE.mov	Documents/2 América-PE/Profissional/Jogos e Cortes/1 TEMPO AMISTOSO AMERICA X SANTA FE.mov
mv	Documents/América-PE/Jogos/1 tempo Amistoso America x Serrano.mov	Documents/2 América-PE/Profissional/Jogos e Cortes/1 tempo Amistoso America x Serrano.mov
mv	Documents/América-PE/Jogos/1 tempo América x Naútico.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/1 tempo América x Naútico.mov
mv	Documents/América-PE/Jogos/1 tempo América x Vitória.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/1 tempo América x Vitória.mov
mv	Documents/América-PE/Jogos/1 tempo america x guarany.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/1 tempo america x guarany.mov
mv	Documents/América-PE/Jogos/1 tempo america x jaguar.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/1 tempo america x jaguar.mov
mv	Documents/América-PE/Jogos/1 tempo america x petrolina.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/1 tempo america x petrolina.mov
mv	Documents/América-PE/Jogos/1 tempo america x serrano.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/1 tempo america x serrano.mov
mv	Documents/América-PE/Jogos/1 tempo amistoso treze pb.mov	Documents/2 América-PE/Profissional/Jogos e Cortes/1 tempo amistoso treze pb.mov
mv	Documents/América-PE/Jogos/1 tempo copa do brasil.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/1 tempo copa do brasil.mov
mv	Documents/América-PE/Jogos/1o Tempo amistoso Torres.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/1o Tempo amistoso Torres.mov
mv	Documents/América-PE/Jogos/1º Tempo amistoso contra 17.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/1º Tempo amistoso contra 17.mov
mv	Documents/América-PE/Jogos/2 TEMPO AMERICA X SANTA FE.mov	Documents/2 América-PE/Profissional/Jogos e Cortes/2 TEMPO AMERICA X SANTA FE.mov
mv	Documents/América-PE/Jogos/2 TEMPO AMERICA X SERRANO.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/2 TEMPO AMERICA X SERRANO.mov
mv	Documents/América-PE/Jogos/2 tempo Amistoso América x Serrano.mov	Documents/2 América-PE/Profissional/Jogos e Cortes/2 tempo Amistoso América x Serrano.mov
mv	Documents/América-PE/Jogos/2 tempo América x Naútico.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/2 tempo América x Naútico.mov
mv	Documents/América-PE/Jogos/2 tempo América x Vitória.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/2 tempo América x Vitória.mov
mv	Documents/América-PE/Jogos/2 tempo X Torres.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/2 tempo X Torres.mov
mv	Documents/América-PE/Jogos/2 tempo america x guarany.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/2 tempo america x guarany.mov
mv	Documents/América-PE/Jogos/2 tempo america x jaguar.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/2 tempo america x jaguar.mov
mv	Documents/América-PE/Jogos/2 tempo america x petrolina.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/2 tempo america x petrolina.mov
mv	Documents/América-PE/Jogos/2 tempo america x serrano( parte 2).mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/2 tempo america x serrano( parte 2).mov
mv	Documents/América-PE/Jogos/2 tempo amistoso treze pb.mov	Documents/2 América-PE/Profissional/Jogos e Cortes/2 tempo amistoso treze pb.mov
mv	Documents/América-PE/Jogos/2 tempo copa do brasil.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/2 tempo copa do brasil.mov
mv	Documents/América-PE/Jogos/2º Tempo amistoso contra 17.mov	Documents/2 América-PE/Sub-20/Jogos e Cortes/2º Tempo amistoso contra 17.mov
rmdir	Documents/América-PE/Jogos	
mv	Documents/América-PE/Modelo de Jogo/Analise Adversario - PNG	Documents/2 América-PE/A definir/Relatórios e Treinos/Analise Adversario - PNG
mv	Documents/América-PE/Modelo de Jogo/Slide deck sobre princípios (1).zip	Documents/2 América-PE/Profissional/Relatórios e Treinos/Slide deck sobre princípios (1).zip
mv	Documents/América-PE/Modelo de Jogo/Slide deck sobre princípios (2).zip	Documents/2 América-PE/Profissional/Relatórios e Treinos/Slide deck sobre princípios (2).zip
mv	Documents/América-PE/Modelo de Jogo/Slide deck sobre princípios (3).zip	Documents/2 América-PE/Profissional/Relatórios e Treinos/Slide deck sobre princípios (3).zip
mv	Documents/América-PE/Modelo de Jogo/Slide deck sobre princípios (4).zip	Documents/2 América-PE/Profissional/Relatórios e Treinos/Slide deck sobre princípios (4).zip
mv	Documents/América-PE/Modelo de Jogo/Slide deck sobre princípios (5).zip	Documents/2 América-PE/Profissional/Relatórios e Treinos/Slide deck sobre princípios (5).zip
mv	Documents/América-PE/Modelo de Jogo/Slide deck sobre princípios.zip	Documents/2 América-PE/Profissional/Relatórios e Treinos/Slide deck sobre princípios.zip
rmdir	Documents/América-PE/Modelo de Jogo	
mv	Documents/América-PE/Relatórios/Autoanálise América FC.pdf	Documents/2 América-PE/Profissional/Relatórios e Treinos/Autoanálise América FC.pdf
mv	Documents/América-PE/Relatórios/Controle de Cartões · 15ª Rodada (1).pdf	Documents/2 América-PE/Sub-20/Relatórios e Treinos/Controle de Cartões · 15ª Rodada (1).pdf
mv	Documents/América-PE/Relatórios/Controle de Cartões · 15ª Rodada.pdf	Documents/2 América-PE/Sub-20/Relatórios e Treinos/Controle de Cartões · 15ª Rodada.pdf
mv	Documents/América-PE/Relatórios/ESCUDO AMERICA.png	Documents/2 América-PE/Clube/ESCUDO AMERICA.png
mv	Documents/América-PE/Relatórios/Elenco América FC.pdf	Documents/2 América-PE/Profissional/Relatórios e Treinos/Elenco América FC.pdf
mv	Documents/América-PE/Relatórios/Elenco Profissional América FC - Elenco Profissional.pdf	Documents/2 América-PE/Profissional/Relatórios e Treinos/Elenco Profissional América FC - Elenco Profissional.pdf
mv	Documents/América-PE/Relatórios/Elenco Profissional América FC.xlsx	Documents/2 América-PE/Profissional/Relatórios e Treinos/Elenco Profissional América FC.xlsx
mv	Documents/América-PE/Relatórios/Elenco Profissional- América FC.pdf	Documents/2 América-PE/Profissional/Relatórios e Treinos/Elenco Profissional- América FC.pdf
mv	Documents/América-PE/Relatórios/MODELO DE JOGO AMÉRICA-PE (BASE).pdf	Documents/2 América-PE/Clube/MODELO DE JOGO AMÉRICA-PE (BASE).pdf
mv	Documents/América-PE/Relatórios/Relatório Amistoso América FC x Petrolina.pdf	Documents/2 América-PE/Sub-20/Relatórios e Treinos/Relatório Amistoso América FC x Petrolina.pdf
mv	Documents/América-PE/Relatórios/Relatório Amistoso América FC x Torres.jpg	Documents/2 América-PE/Sub-20/Relatórios e Treinos/Relatório Amistoso América FC x Torres.jpg
mv	Documents/América-PE/Relatórios/Relatório Amistoso América FC x Torres.pdf	Documents/2 América-PE/Sub-20/Relatórios e Treinos/Relatório Amistoso América FC x Torres.pdf
mv	Documents/América-PE/Relatórios/Relatório Amistoso América FC.pdf	Documents/2 América-PE/Profissional/Relatórios e Treinos/Relatório Amistoso América FC.pdf
mv	Documents/América-PE/Relatórios/Relatório América FC x Petrolina.pdf	Documents/2 América-PE/Sub-20/Relatórios e Treinos/Relatório América FC x Petrolina.pdf
mv	Documents/América-PE/Relatórios/Relatório dados Amistoso.pdf	Documents/2 América-PE/Profissional/Relatórios e Treinos/Relatório dados Amistoso.pdf
rmdir	Documents/América-PE/Relatórios	
mv	Documents/América-PE/Treinos/Mini campinho para treinos 2.pdf	Documents/2 América-PE/Clube/Mini campinho para treinos 2.pdf
mv	Documents/América-PE/Treinos/Mini campinho para treinos.pdf	Documents/2 América-PE/Clube/Mini campinho para treinos.pdf
mv	Documents/América-PE/Treinos/Plano de Treino 08 10.pdf	Documents/2 América-PE/Profissional/Relatórios e Treinos/Plano de Treino 08 10.pdf
mv	Documents/América-PE/Treinos/Plano de Treino 1006 (1).pdf	Documents/2 América-PE/Profissional/Relatórios e Treinos/Plano de Treino 1006 (1).pdf
mv	Documents/América-PE/Treinos/Plano de Treino 1006 (10).pdf	Documents/2 América-PE/Profissional/Relatórios e Treinos/Plano de Treino 1006 (10).pdf
mv	Documents/América-PE/Treinos/Plano de Treino 1006 (11).pdf	Documents/2 América-PE/Profissional/Relatórios e Treinos/Plano de Treino 1006 (11).pdf
mv	Documents/América-PE/Treinos/Plano de Treino 1006 (12).pdf	Documents/2 América-PE/Profissional/Relatórios e Treinos/Plano de Treino 1006 (12).pdf
mv	Documents/América-PE/Treinos/Plano de Treino 1006 (13).pdf	Documents/2 América-PE/Profissional/Relatórios e Treinos/Plano de Treino 1006 (13).pdf
mv	Documents/América-PE/Treinos/Plano de Treino 1006 (14).pdf	Documents/2 América-PE/Profissional/Relatórios e Treinos/Plano de Treino 1006 (14).pdf
mv	Documents/América-PE/Treinos/Plano de Treino 1006 (15).pdf	Documents/2 América-PE/Profissional/Relatórios e Treinos/Plano de Treino 1006 (15).pdf
mv	Documents/América-PE/Treinos/Plano de Treino 1006 (16).pdf	Documents/2 América-PE/Profissional/Relatórios e Treinos/Plano de Treino 1006 (16).pdf
mv	Documents/América-PE/Treinos/Plano de Treino 1006 (17).pdf	Documents/2 América-PE/Profissional/Relatórios e Treinos/Plano de Treino 1006 (17).pdf
mv	Documents/América-PE/Treinos/Plano de Treino 1006 (18).pdf	Documents/2 América-PE/Profissional/Relatórios e Treinos/Plano de Treino 1006 (18).pdf
mv	Documents/América-PE/Treinos/Plano de Treino 1006 (19).pdf	Documents/2 América-PE/Profissional/Relatórios e Treinos/Plano de Treino 1006 (19).pdf
mv	Documents/América-PE/Treinos/Plano de Treino 1006 (2).pdf	Documents/2 América-PE/Profissional/Relatórios e Treinos/Plano de Treino 1006 (2).pdf
mv	Documents/América-PE/Treinos/Plano de Treino 1006 (20).pdf	Documents/2 América-PE/Profissional/Relatórios e Treinos/Plano de Treino 1006 (20).pdf
mv	Documents/América-PE/Treinos/Plano de Treino 1006 (3).pdf	Documents/2 América-PE/Profissional/Relatórios e Treinos/Plano de Treino 1006 (3).pdf
mv	Documents/América-PE/Treinos/Plano de Treino 1006 (4).pdf	Documents/2 América-PE/Profissional/Relatórios e Treinos/Plano de Treino 1006 (4).pdf
mv	Documents/América-PE/Treinos/Plano de Treino 1006 (5).pdf	Documents/2 América-PE/Profissional/Relatórios e Treinos/Plano de Treino 1006 (5).pdf
mv	Documents/América-PE/Treinos/Plano de Treino 1006 (6).pdf	Documents/2 América-PE/Profissional/Relatórios e Treinos/Plano de Treino 1006 (6).pdf
mv	Documents/América-PE/Treinos/Plano de Treino 1006 (7).pdf	Documents/2 América-PE/Profissional/Relatórios e Treinos/Plano de Treino 1006 (7).pdf
mv	Documents/América-PE/Treinos/Plano de Treino 1006 (8).pdf	Documents/2 América-PE/Profissional/Relatórios e Treinos/Plano de Treino 1006 (8).pdf
mv	Documents/América-PE/Treinos/Plano de Treino 1006 (9).pdf	Documents/2 América-PE/Profissional/Relatórios e Treinos/Plano de Treino 1006 (9).pdf
mv	Documents/América-PE/Treinos/Plano de Treino 1006.pdf	Documents/2 América-PE/Sub-20/Relatórios e Treinos/Plano de Treino 1006.pdf
mv	Documents/América-PE/Treinos/Plano de Treino(02 10).pdf	Documents/2 América-PE/Profissional/Relatórios e Treinos/Plano de Treino(02 10).pdf
rmdir	Documents/América-PE/Treinos	
rmdir	Documents/América-PE	
rmdir	Documents/Benfica/Fotos e Vídeos	
rmdir	Documents/Benfica/Planos de Aula e Treinos	
mv	Documents/Benfica	Documents/3 Benfica
mv	Documents/Pessoal/Diego Avelar	Documents/4 Alunos/Diego Avelar
mv	Documents/Pessoal	Documents/7 Pessoal
mv	Documents/Projetos Claude	Documents/8 Projetos
mv	Documents/Estudos	Documents/5 Estudos
mv	Documents/Faculdade/2023 Modelo Termo de compromisso estÃ¡gio nÃ£o obrigatÃ³rio.docx	Documents/6 Faculdade/Estágio/2023 Modelo Termo de compromisso estÃ¡gio nÃ£o obrigatÃ³rio.docx
mv	Documents/Faculdade/ANÁLISE SWOT GESTÃO- SANTA CRUZ.pdf	Documents/6 Faculdade/Disciplinas/ANÁLISE SWOT GESTÃO- SANTA CRUZ.pdf
mv	Documents/Faculdade/AS DIFERENTES ABORDAGENS DE PESQUISA CIENTÍFICA E SUAS CLASSIFICAÇÕES - Souza et al. (2016).pdf	Documents/6 Faculdade/Disciplinas/AS DIFERENTES ABORDAGENS DE PESQUISA CIENTÍFICA E SUAS CLASSIFICAÇÕES - Souza et al. (2016).pdf
mv	Documents/Faculdade/ATIVIDADE ARTIGOS.docx	Documents/6 Faculdade/Disciplinas/ATIVIDADE ARTIGOS.docx
mv	Documents/Faculdade/AULA CDH BLOCO 2 Avaliação do Crescimento Fisico.pdf	Documents/6 Faculdade/Disciplinas/AULA CDH BLOCO 2 Avaliação do Crescimento Fisico.pdf
mv	Documents/Faculdade/AULA REFERENCIAIS NORMATIVOS.pdf	Documents/6 Faculdade/Disciplinas/AULA REFERENCIAIS NORMATIVOS.pdf
mv	Documents/Faculdade/AVALIAÇÕES - 2023.2 - FTMJ.xlsx	Documents/6 Faculdade/Disciplinas/AVALIAÇÕES - 2023.2 - FTMJ.xlsx
mv	Documents/Faculdade/Apostila Diabetes 2026.1.docx	Documents/6 Faculdade/Disciplinas/Apostila Diabetes 2026.1.docx
mv	Documents/Faculdade/Atividade Esportes.pdf	Documents/6 Faculdade/Disciplinas/Atividade Esportes.pdf
mv	Documents/Faculdade/Aula 06 TCM Convecao Escoamento rev01.pdf	Documents/6 Faculdade/Disciplinas/Aula 06 TCM Convecao Escoamento rev01.pdf
mv	Documents/Faculdade/BACHARELADO Origens Desenvolvimentistas da Saude e Doença.pdf	Documents/6 Faculdade/Disciplinas/BACHARELADO Origens Desenvolvimentistas da Saude e Doença.pdf
mv	Documents/Faculdade/BLOCO DE SLIDES 1 CDH 2023.pdf	Documents/6 Faculdade/Disciplinas/BLOCO DE SLIDES 1 CDH 2023.pdf
mv	Documents/Faculdade/Conferência Internacional de Promoção da Saúde.pptx	Documents/6 Faculdade/Disciplinas/Conferência Internacional de Promoção da Saúde.pptx
mv	Documents/Faculdade/DECLARACAO DE ACEITE DE SUPERVISAO DO ESTAGIO OBRIGATORIO - BACHARELADO.pdf	Documents/6 Faculdade/Estágio/DECLARACAO DE ACEITE DE SUPERVISAO DO ESTAGIO OBRIGATORIO - BACHARELADO.pdf
mv	Documents/Faculdade/DECLARAÇÃO DE ACEITE DE SUPERVISÃO DO ESTÁGIO OBRIGATÓRIO - BACHARELADO.doc (1).pdf	Documents/6 Faculdade/Estágio/DECLARAÇÃO DE ACEITE DE SUPERVISÃO DO ESTÁGIO OBRIGATÓRIO - BACHARELADO.doc (1).pdf
mv	Documents/Faculdade/DECLARAÇÃO DE ACEITE DE SUPERVISÃO DO ESTÁGIO OBRIGATÓRIO - BACHARELADO.doc (2) (1).pdf	Documents/6 Faculdade/Estágio/DECLARAÇÃO DE ACEITE DE SUPERVISÃO DO ESTÁGIO OBRIGATÓRIO - BACHARELADO.doc (2) (1).pdf
mv	Documents/Faculdade/DECLARAÇÃO DE ACEITE DE SUPERVISÃO DO ESTÁGIO OBRIGATÓRIO - BACHARELADO.doc (2) (2).pdf	Documents/6 Faculdade/Estágio/DECLARAÇÃO DE ACEITE DE SUPERVISÃO DO ESTÁGIO OBRIGATÓRIO - BACHARELADO.doc (2) (2).pdf
mv	Documents/Faculdade/DECLARAÇÃO DE ACEITE DE SUPERVISÃO DO ESTÁGIO OBRIGATÓRIO - BACHARELADO.doc (2).docx	Documents/6 Faculdade/Estágio/DECLARAÇÃO DE ACEITE DE SUPERVISÃO DO ESTÁGIO OBRIGATÓRIO - BACHARELADO.doc (2).docx
mv	Documents/Faculdade/DECLARAÇÃO DE ACEITE DE SUPERVISÃO DO ESTÁGIO OBRIGATÓRIO - BACHARELADO.doc (2).pdf	Documents/6 Faculdade/Estágio/DECLARAÇÃO DE ACEITE DE SUPERVISÃO DO ESTÁGIO OBRIGATÓRIO - BACHARELADO.doc (2).pdf
mv	Documents/Faculdade/DECLARAÇÃO DE ACEITE DE SUPERVISÃO DO ESTÁGIO OBRIGATÓRIO - BACHARELADO.docx	Documents/6 Faculdade/Estágio/DECLARAÇÃO DE ACEITE DE SUPERVISÃO DO ESTÁGIO OBRIGATÓRIO - BACHARELADO.docx
mv	Documents/Faculdade/DECLARAÇÃO DE ACEITE DE SUPERVISÃO DO ESTÁGIO OBRIGATÓRIO - BACHARELADO.pdf	Documents/6 Faculdade/Estágio/DECLARAÇÃO DE ACEITE DE SUPERVISÃO DO ESTÁGIO OBRIGATÓRIO - BACHARELADO.pdf
mv	Documents/Faculdade/Documentos estágio organized.pdf	Documents/6 Faculdade/Estágio/Documentos estágio organized.pdf
mv	Documents/Faculdade/Documentos estágio.pdf	Documents/6 Faculdade/Estágio/Documentos estágio.pdf
mv	Documents/Faculdade/ESEF UPE.pdf	Documents/6 Faculdade/Disciplinas/ESEF UPE.pdf
mv	Documents/Faculdade/ESTUDO DE CASO (1).pdf	Documents/6 Faculdade/Disciplinas/ESTUDO DE CASO (1).pdf
mv	Documents/Faculdade/ESTUDO DE CASO.docx	Documents/6 Faculdade/Disciplinas/ESTUDO DE CASO.docx
mv	Documents/Faculdade/ESTUDO DE CASO.pdf	Documents/6 Faculdade/Disciplinas/ESTUDO DE CASO.pdf
mv	Documents/Faculdade/Estratificação de risco 1 (1).docx	Documents/6 Faculdade/Disciplinas/Estratificação de risco 1 (1).docx
mv	Documents/Faculdade/Estratificação de risco 1.docx	Documents/6 Faculdade/Disciplinas/Estratificação de risco 1.docx
mv	Documents/Faculdade/Estratificação de risco 1.pdf	Documents/6 Faculdade/Disciplinas/Estratificação de risco 1.pdf
mv	Documents/Faculdade/Estratificação de risco 2.docx	Documents/6 Faculdade/Disciplinas/Estratificação de risco 2.docx
mv	Documents/Faculdade/Estratificação de risco 2.pdf	Documents/6 Faculdade/Disciplinas/Estratificação de risco 2.pdf
mv	Documents/Faculdade/Estágio Gabriel Vitor.docx	Documents/6 Faculdade/Estágio/Estágio Gabriel Vitor.docx
mv	Documents/Faculdade/Estágio Gabriel Vitor.docx (1).pdf	Documents/6 Faculdade/Estágio/Estágio Gabriel Vitor.docx (1).pdf
mv	Documents/Faculdade/Estágio Gabriel Vitor.docx (2).docx	Documents/6 Faculdade/Estágio/Estágio Gabriel Vitor.docx (2).docx
mv	Documents/Faculdade/Estágio Gabriel Vitor.docx (2).pdf	Documents/6 Faculdade/Estágio/Estágio Gabriel Vitor.docx (2).pdf
mv	Documents/Faculdade/Estágio Gabriel Vitor.pdf	Documents/6 Faculdade/Estágio/Estágio Gabriel Vitor.pdf
mv	Documents/Faculdade/FACULDADE - APRESENTAÇÃO - EXERGAMES E EXERCÍCIO AERÓBICO NO DIABETES TIPO 1 - David Gabriel, Gabriel Vitor e Vinicius Branco.pdf	Documents/6 Faculdade/Disciplinas/FACULDADE - APRESENTAÇÃO - EXERGAMES E EXERCÍCIO AERÓBICO NO DIABETES TIPO 1 - David Gabriel, Gabriel Vitor e Vinicius Branco.pdf
mv	Documents/Faculdade/FACULDADE - APRESENTAÇÃO - FISIOLOGIA DA FUNÇÃO RENAL - Souza et al. (2024).pdf	Documents/6 Faculdade/Disciplinas/FACULDADE - APRESENTAÇÃO - FISIOLOGIA DA FUNÇÃO RENAL - Souza et al. (2024).pdf
mv	Documents/Faculdade/FACULDADE - APRESENTAÇÃO - FISIOLOGIA DA MICÇÃO - Batista et al. (2024).pdf	Documents/6 Faculdade/Disciplinas/FACULDADE - APRESENTAÇÃO - FISIOLOGIA DA MICÇÃO - Batista et al. (2024).pdf
mv	Documents/Faculdade/FACULDADE - APRESENTAÇÃO - FISIOLOGIA DA SECREÇÃO RENAL - Ginnari et al. (2024).pdf	Documents/6 Faculdade/Disciplinas/FACULDADE - APRESENTAÇÃO - FISIOLOGIA DA SECREÇÃO RENAL - Ginnari et al. (2024).pdf
mv	Documents/Faculdade/FACULDADE - APRESENTAÇÃO - FISIOLOGIA DOS RINS - Oliveira et al. (2024).pdf	Documents/6 Faculdade/Disciplinas/FACULDADE - APRESENTAÇÃO - FISIOLOGIA DOS RINS - Oliveira et al. (2024).pdf
mv	Documents/Faculdade/FACULDADE - APRESENTAÇÃO DE NEGÓCIO - MODERN FUT - Grupo Gabriel Vitor (2025).pdf	Documents/6 Faculdade/Disciplinas/FACULDADE - APRESENTAÇÃO DE NEGÓCIO - MODERN FUT - Grupo Gabriel Vitor (2025).pdf
mv	Documents/Faculdade/FACULDADE - APRESENTAÇÃO DE NEGÓCIO - MODERN FUT - Grupo Gabriel Vitor (2026).pdf	Documents/6 Faculdade/Disciplinas/FACULDADE - APRESENTAÇÃO DE NEGÓCIO - MODERN FUT - Grupo Gabriel Vitor (2026).pdf
mv	Documents/Faculdade/FACULDADE - ATIVIDADE FISIOLOGIA DO SISTEMA RESPIRATÓRIO - Gabriel Vitor (2023).pdf	Documents/6 Faculdade/Disciplinas/FACULDADE - ATIVIDADE FISIOLOGIA DO SISTEMA RESPIRATÓRIO - Gabriel Vitor (2023).pdf
mv	Documents/Faculdade/FACULDADE - ATIVIDADE FÍSICA E SAÚDE MENTAL - Grupo Gabriel Vitor.pdf	Documents/6 Faculdade/Disciplinas/FACULDADE - ATIVIDADE FÍSICA E SAÚDE MENTAL - Grupo Gabriel Vitor.pdf
mv	Documents/Faculdade/FACULDADE - DECLARAÇÃO DE ACEITE DE SUPERVISÃO DE ESTÁGIO E DOCUMENTOS.pdf	Documents/6 Faculdade/Estágio/FACULDADE - DECLARAÇÃO DE ACEITE DE SUPERVISÃO DE ESTÁGIO E DOCUMENTOS.pdf
mv	Documents/Faculdade/FACULDADE - FICHA ANTROPOMÉTRICA - Gabriel Vitor e Vinicius Branco (2025).pdf	Documents/6 Faculdade/Disciplinas/FACULDADE - FICHA ANTROPOMÉTRICA - Gabriel Vitor e Vinicius Branco (2025).pdf
mv	Documents/Faculdade/FACULDADE - METODOLOGIA DOS ESPORTES COLETIVOS - ATIVIDADES - Grupo Gabriel Vitor.pdf	Documents/6 Faculdade/Disciplinas/FACULDADE - METODOLOGIA DOS ESPORTES COLETIVOS - ATIVIDADES - Grupo Gabriel Vitor.pdf
mv	Documents/Faculdade/FACULDADE - PLANO MODALIDADE FUTSAL (2026).pdf	Documents/6 Faculdade/Disciplinas/FACULDADE - PLANO MODALIDADE FUTSAL (2026).pdf
mv	Documents/Faculdade/FACULDADE - RELATÓRIO DE ESTÁGIO SUPERVISIONADO III - LAZER - Gabriel Vitor (2).pdf	Documents/6 Faculdade/Estágio/FACULDADE - RELATÓRIO DE ESTÁGIO SUPERVISIONADO III - LAZER - Gabriel Vitor (2).pdf
mv	Documents/Faculdade/FACULDADE - RELATÓRIO DE ESTÁGIO SUPERVISIONADO III - LAZER - Gabriel Vitor.pdf	Documents/6 Faculdade/Estágio/FACULDADE - RELATÓRIO DE ESTÁGIO SUPERVISIONADO III - LAZER - Gabriel Vitor.pdf
mv	Documents/Faculdade/FACULDADE - RELATÓRIO DE EXPERIÊNCIA - TRIAGEM PRÉ-EXERCÍCIO - Gabriel Vitor.pdf	Documents/6 Faculdade/Disciplinas/FACULDADE - RELATÓRIO DE EXPERIÊNCIA - TRIAGEM PRÉ-EXERCÍCIO - Gabriel Vitor.pdf
mv	Documents/Faculdade/FACULDADE - RELATÓRIO DE MONITORIA VÔLEI - Carolina Monique (2023).pdf	Documents/6 Faculdade/Disciplinas/FACULDADE - RELATÓRIO DE MONITORIA VÔLEI - Carolina Monique (2023).pdf
mv	Documents/Faculdade/FACULDADE - RESUMO DE ARTIGO - ABORDAGENS DE PESQUISA CIENTÍFICA - Gabriel Vitor.pdf	Documents/6 Faculdade/Disciplinas/FACULDADE - RESUMO DE ARTIGO - ABORDAGENS DE PESQUISA CIENTÍFICA - Gabriel Vitor.pdf
mv	Documents/Faculdade/FACULDADE - RESUMO DE ARTIGO - PROMOÇÃO DA SAÚDE E LINHA DO TEMPO - Gabriel Vitor (2).pdf	Documents/6 Faculdade/Disciplinas/FACULDADE - RESUMO DE ARTIGO - PROMOÇÃO DA SAÚDE E LINHA DO TEMPO - Gabriel Vitor (2).pdf
mv	Documents/Faculdade/FACULDADE - RESUMO DE ARTIGO - PROMOÇÃO DA SAÚDE E LINHA DO TEMPO - Gabriel Vitor.pdf	Documents/6 Faculdade/Disciplinas/FACULDADE - RESUMO DE ARTIGO - PROMOÇÃO DA SAÚDE E LINHA DO TEMPO - Gabriel Vitor.pdf
mv	Documents/Faculdade/FACULDADE - VISITA TÉCNICA ESCOLINHA INOCOOP CITY - Grupo Gabriel Vitor (2026).pdf	Documents/6 Faculdade/Disciplinas/FACULDADE - VISITA TÉCNICA ESCOLINHA INOCOOP CITY - Grupo Gabriel Vitor (2026).pdf
mv	Documents/Faculdade/FICHA DE AVALIAÇÃO DO A SUPERVISOR A.pdf	Documents/6 Faculdade/Estágio/FICHA DE AVALIAÇÃO DO A SUPERVISOR A.pdf
mv	Documents/Faculdade/FICHA DE FREQUÊNCIA DO ESTAGIÁRIO - BACHARELADO.pdf	Documents/6 Faculdade/Estágio/FICHA DE FREQUÊNCIA DO ESTAGIÁRIO - BACHARELADO.pdf
mv	Documents/Faculdade/METODOLOGIA DA PESQUISA - Silva (2017) (livro).pdf	Documents/6 Faculdade/Disciplinas/METODOLOGIA DA PESQUISA - Silva (2017) (livro).pdf
mv	Documents/Faculdade/MODELO DO RELATÓRIO DAS ATIVIDADES DE ESTÁGIO.pdf	Documents/6 Faculdade/Estágio/MODELO DO RELATÓRIO DAS ATIVIDADES DE ESTÁGIO.pdf
mv	Documents/Faculdade/MODELO Termo de Anuência.doc	Documents/6 Faculdade/Disciplinas/MODELO Termo de Anuência.doc
mv	Documents/Faculdade/MODELO-DE-PLANO-DE-AULA.doc	Documents/6 Faculdade/Disciplinas/MODELO-DE-PLANO-DE-AULA.doc
mv	Documents/Faculdade/PLANO DE ATIVIDADE ASSINADO.pdf	Documents/6 Faculdade/Estágio/PLANO DE ATIVIDADE ASSINADO.pdf
mv	Documents/Faculdade/PLANO DE ATIVIDADES DO ESTAGIO CURRICULAR OBRIGATORIO - BACHARELADO (2) (1) (1).docx	Documents/6 Faculdade/Estágio/PLANO DE ATIVIDADES DO ESTAGIO CURRICULAR OBRIGATORIO - BACHARELADO (2) (1) (1).docx
mv	Documents/Faculdade/PLANO DE ATIVIDADES DO ESTAGIO CURRICULAR OBRIGATORIO - BACHARELADO (2) (1) (1).pdf	Documents/6 Faculdade/Estágio/PLANO DE ATIVIDADES DO ESTAGIO CURRICULAR OBRIGATORIO - BACHARELADO (2) (1) (1).pdf
mv	Documents/Faculdade/PLANO DE ATIVIDADES DO ESTAGIO CURRICULAR OBRIGATORIO - BACHARELADO (2) (1).docx	Documents/6 Faculdade/Estágio/PLANO DE ATIVIDADES DO ESTAGIO CURRICULAR OBRIGATORIO - BACHARELADO (2) (1).docx
mv	Documents/Faculdade/PLANO DE ATIVIDADES DO ESTAGIO CURRICULAR OBRIGATORIO - BACHARELADO (2) (1).pdf	Documents/6 Faculdade/Estágio/PLANO DE ATIVIDADES DO ESTAGIO CURRICULAR OBRIGATORIO - BACHARELADO (2) (1).pdf
mv	Documents/Faculdade/PLANO DE ATIVIDADES DO ESTÁGIO CURRICULAR OBRIGATÓRIO - BACHARELADO (2) (1).docx	Documents/6 Faculdade/Estágio/PLANO DE ATIVIDADES DO ESTÁGIO CURRICULAR OBRIGATÓRIO - BACHARELADO (2) (1).docx
mv	Documents/Faculdade/PLANO DE ATIVIDADES DO ESTÁGIO CURRICULAR OBRIGATÓRIO - BACHARELADO (2).docx	Documents/6 Faculdade/Estágio/PLANO DE ATIVIDADES DO ESTÁGIO CURRICULAR OBRIGATÓRIO - BACHARELADO (2).docx
mv	Documents/Faculdade/PLANO DE ATIVIDADES DO ESTÁGIO CURRICULAR OBRIGATÓRIO - BACHARELADO.pdf	Documents/6 Faculdade/Estágio/PLANO DE ATIVIDADES DO ESTÁGIO CURRICULAR OBRIGATÓRIO - BACHARELADO.pdf
mv	Documents/Faculdade/PNPS atualizada.pdf	Documents/6 Faculdade/Disciplinas/PNPS atualizada.pdf
mv	Documents/Faculdade/PROMOÇÃO À SAÚDE TRAJETÓRIA HISTÓRICA DE SUAS CONCEPÇÕES.pdf	Documents/6 Faculdade/Disciplinas/PROMOÇÃO À SAÚDE TRAJETÓRIA HISTÓRICA DE SUAS CONCEPÇÕES.pdf
mv	Documents/Faculdade/Plano de atividade.pdf	Documents/6 Faculdade/Estágio/Plano de atividade.pdf
mv	Documents/Faculdade/Plano de aula - Futebol-1-1.docx	Documents/6 Faculdade/Disciplinas/Plano de aula - Futebol-1-1.docx
mv	Documents/Faculdade/Plano de aula - Futebol.pdf	Documents/6 Faculdade/Disciplinas/Plano de aula - Futebol.pdf
mv	Documents/Faculdade/Plano de aula TEPT.pdf	Documents/6 Faculdade/Disciplinas/Plano de aula TEPT.pdf
mv	Documents/Faculdade/Plano de aula.pdf	Documents/6 Faculdade/Disciplinas/Plano de aula.pdf
mv	Documents/Faculdade/RELATORIO DE MONITORIA em branco.docx	Documents/6 Faculdade/Disciplinas/RELATORIO DE MONITORIA em branco.docx
mv	Documents/Faculdade/Relatorio de Estagio - Nuno Vieira.pdf	Documents/6 Faculdade/Estágio/Relatorio de Estagio - Nuno Vieira.pdf
mv	Documents/Faculdade/Simple SWOT Analysis Diagram Infographic (1).pdf	Documents/6 Faculdade/Disciplinas/Simple SWOT Analysis Diagram Infographic (1).pdf
mv	Documents/Faculdade/Simple SWOT Analysis Diagram Infographic (2).pdf	Documents/6 Faculdade/Disciplinas/Simple SWOT Analysis Diagram Infographic (2).pdf
mv	Documents/Faculdade/Simple SWOT Analysis Diagram Infographic (3).pdf	Documents/6 Faculdade/Disciplinas/Simple SWOT Analysis Diagram Infographic (3).pdf
mv	Documents/Faculdade/Simple SWOT Analysis Diagram Infographic.pdf	Documents/6 Faculdade/Disciplinas/Simple SWOT Analysis Diagram Infographic.pdf
mv	Documents/Faculdade/TEPT MAPAS MENTAIS	Documents/6 Faculdade/Disciplinas/TEPT MAPAS MENTAIS
mv	Documents/Faculdade/TERMO DE COMPROMISSO DE ESTAGIO CURRICULAR OBRIGATORIO BACHARELADO.pdf	Documents/6 Faculdade/Estágio/TERMO DE COMPROMISSO DE ESTAGIO CURRICULAR OBRIGATORIO BACHARELADO.pdf
mv	Documents/Faculdade/TERMO DE COMPROMISSO DE ESTÁGIO CURRICULAR OBRIGATÓRIO BACHARELADO.docx	Documents/6 Faculdade/Estágio/TERMO DE COMPROMISSO DE ESTÁGIO CURRICULAR OBRIGATÓRIO BACHARELADO.docx
mv	Documents/Faculdade/TERMO DE COMPROMISSO DE ESTÁGIO CURRICULAR OBRIGATÓRIO BACHARELADO.docx (1) (1).pdf	Documents/6 Faculdade/Estágio/TERMO DE COMPROMISSO DE ESTÁGIO CURRICULAR OBRIGATÓRIO BACHARELADO.docx (1) (1).pdf
mv	Documents/Faculdade/TERMO DE COMPROMISSO DE ESTÁGIO CURRICULAR OBRIGATÓRIO BACHARELADO.docx (1) (2).pdf	Documents/6 Faculdade/Estágio/TERMO DE COMPROMISSO DE ESTÁGIO CURRICULAR OBRIGATÓRIO BACHARELADO.docx (1) (2).pdf
mv	Documents/Faculdade/TERMO DE COMPROMISSO DE ESTÁGIO CURRICULAR OBRIGATÓRIO BACHARELADO.docx (1).pdf	Documents/6 Faculdade/Estágio/TERMO DE COMPROMISSO DE ESTÁGIO CURRICULAR OBRIGATÓRIO BACHARELADO.docx (1).pdf
mv	Documents/Faculdade/TERMO DE COMPROMISSO DE ESTÁGIO CURRICULAR OBRIGATÓRIO BACHARELADO.docx (2).docx	Documents/6 Faculdade/Estágio/TERMO DE COMPROMISSO DE ESTÁGIO CURRICULAR OBRIGATÓRIO BACHARELADO.docx (2).docx
mv	Documents/Faculdade/TERMO DE COMPROMISSO DE ESTÁGIO CURRICULAR OBRIGATÓRIO BACHARELADO.docx (2).pdf	Documents/6 Faculdade/Estágio/TERMO DE COMPROMISSO DE ESTÁGIO CURRICULAR OBRIGATÓRIO BACHARELADO.docx (2).pdf
mv	Documents/Faculdade/TERMO DE COMPROMISSO DE ESTÁGIO CURRICULAR OBRIGATÓRIO BACHARELADO.pdf	Documents/6 Faculdade/Estágio/TERMO DE COMPROMISSO DE ESTÁGIO CURRICULAR OBRIGATÓRIO BACHARELADO.pdf
mv	Documents/Faculdade/TERMO DE ENCAMINHAMENTO AO ESTÁGIO OBRIGATÓRIO - BACHARELADO (1).docx	Documents/6 Faculdade/Estágio/TERMO DE ENCAMINHAMENTO AO ESTÁGIO OBRIGATÓRIO - BACHARELADO (1).docx
mv	Documents/Faculdade/TERMO DE ENCAMINHAMENTO AO ESTÁGIO OBRIGATÓRIO - BACHARELADO (1).pdf	Documents/6 Faculdade/Estágio/TERMO DE ENCAMINHAMENTO AO ESTÁGIO OBRIGATÓRIO - BACHARELADO (1).pdf
mv	Documents/Faculdade/TERMO DE ENCAMINHAMENTO AO ESTÁGIO OBRIGATÓRIO - BACHARELADO.docx	Documents/6 Faculdade/Estágio/TERMO DE ENCAMINHAMENTO AO ESTÁGIO OBRIGATÓRIO - BACHARELADO.docx
mv	Documents/Faculdade/TERMO DE ENCAMINHAMENTO AO ESTÁGIO OBRIGATÓRIO - BACHARELADO.pdf	Documents/6 Faculdade/Estágio/TERMO DE ENCAMINHAMENTO AO ESTÁGIO OBRIGATÓRIO - BACHARELADO.pdf
mv	Documents/Faculdade/gabriel vitor plano de atividades-esporte 22025.1 (1).docx	Documents/6 Faculdade/Estágio/gabriel vitor plano de atividades-esporte 22025.1 (1).docx
mv	Documents/Faculdade/gabriel vitor plano de atividades-esporte 22025.1.docx	Documents/6 Faculdade/Estágio/gabriel vitor plano de atividades-esporte 22025.1.docx
mv	Documents/Faculdade/gabriel vitor plano de atividades-esporte 22025.1.pdf	Documents/6 Faculdade/Estágio/gabriel vitor plano de atividades-esporte 22025.1.pdf
mv	Documents/Faculdade/modelo plano de aula versao atualizada.doc	Documents/6 Faculdade/Disciplinas/modelo plano de aula versao atualizada.doc
mv	Documents/Faculdade/modelo-termo-assentimento.docx	Documents/6 Faculdade/Disciplinas/modelo-termo-assentimento.docx
mv	Documents/Faculdade/plano de aula prática Brincadeiras com BOLA.pdf	Documents/6 Faculdade/Disciplinas/plano de aula prática Brincadeiras com BOLA.pdf
mv	Documents/Faculdade/prova cdh-1.pdf	Documents/6 Faculdade/Disciplinas/prova cdh-1.pdf
mv	Documents/Faculdade/roteiroBasico.doc	Documents/6 Faculdade/Disciplinas/roteiroBasico.doc
rmdir	Documents/Faculdade	
mv	Documents/Trabalhos Anteriores/Tubarões	Documents/9 Arquivo/Tubarões
mv	Documents/Trabalhos Anteriores/AABB	Documents/9 Arquivo/AABB
rmdir	Documents/Trabalhos Anteriores	
mv	Documents/Arquivo (antes de 2026)	Documents/9 Arquivo/Antes de 2026
mv	Downloads/0 LEIA-ME - Mapa das pastas.pdf	Documents/0 LEIA-ME - Mapa das pastas.pdf
__LISTA__
