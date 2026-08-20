# tmux config — Guia para IA

Config do tmux em `~/.config/tmux/` (path XDG, tmux 3.1+ encontra automaticamente). Integração pesada com Vim (vim-tmux-navigator) e workflow de dev poliglota (Elixir/Phoenix, Rails, JS/React, Python, SQL).

## Estrutura

```
tmux.conf        ← config principal
README.md        ← overview + lista de plugins
CHEATSHEET.md    ← docs operacionais (atalhos, popups, fluxos)
CLAUDE.md        ← este arquivo
test/
  run.sh         ← entry point dos testes (bash test/run.sh)
  lib.sh         ← assertion helpers
  shell.sh       ← checagens estáticas no conf
  integration.sh ← testes dinâmicos com tmux rodando em socket isolado
scripts/
  session-theme.sh ← aplica cores por sessão (work*=ciano, personal*=laranja)
plugins/         ← TPM clona plugins aqui (TMUX_PLUGIN_MANAGER_PATH)
```

## Ordem de carregamento do `tmux.conf`

1. Seção **KEY BINDINGS** (topo) — prefix, splits, pane navigation, popups, copy-mode vi
2. Seção **DESIGN CHANGES** — cores, status bar, true color, undercurl
3. Seção **PLUGINS** — declara plugins + vars de config
4. Linha final: `run '~/.config/tmux/plugins/tpm/tpm'` — TPM carrega plugins
5. **Post-TPM overrides** — o que vem depois do `run` vence plugin defaults

> ⚠️ **Regra de ouro:** `tmux-sensible` faz `set -g status-keys emacs` **unconditionally** quando carrega. Overrides que precisam vencer sensible devem ficar **depois** da linha `run '...'` do TPM. É por isso que `set -g status-keys vi` fica no rodapé.

## Convenções obrigatórias

- **Splits:** `|` (horizontal) e `-` (vertical). Nunca `v`/`s` (eram os antigos, removidos).
- **Popups flutuantes** para ferramentas que se beneficiam de overlay temporário (Claude, lazygit, scratch shell). Pattern: `bind-key X display-popup -E -w W% -h H% -d "#{pane_current_path}" "cmd"`.
- **Pane navigation:** `C-hjkl` (sem prefix) é do `vim-tmux-navigator` — vence dentro do Vim e no tmux. **Nunca** re-binde `C-h/j/k/l` sem usar o `is_vim` check do plugin.
- **`C-l` foi roubado** pelo vim-tmux-navigator. Clear shell é `prefix + C-l` (via `send-keys 'C-l'`).
- **Plugins vão sempre via TPM** — declare com `set -g @plugin 'user/repo'` entre `tpm` e a linha `run`.

## Sistema de testes

```bash
bash test/run.sh              # todas as suites, output compacto
bash test/run.sh -v           # expandido (caso-a-caso)
bash test/run.sh -vv          # debug (stderr do tmux em falhas)
bash test/run.sh shell        # só checagens estáticas
bash test/run.sh integration  # só testes dinâmicos (inicia tmux em socket isolado)
```

| Suite       | O que testa |
|-------------|-------------|
| shell       | Grep estático no conf: regressões, bindings presentes, plugins listados, vars, ranges de sanidade (popup sizes, history-limit, status-interval), consistência temática (vi theme, clipboard macOS, true color chain) |
| structure   | File-level: line-order (TPM é último run, Post-TPM override está depois), dup detection de bindings, encoding UTF-8, BOM, CRLF, permissões, plugin count exato (9), plugin URL format, plugin health (git repo válido, entry file, sem órfãos), `~/.tmux.conf` ausente |
| integration | Sobe tmux com `tmux -L claude-test-$PID -f ~/.config/tmux/tmux.conf`. Valida options (`show-options`) e bindings (`list-keys`) em tempo real — incluindo prefix, root table (M-/S-arrows), copy-mode-vi, plugin bindings (skip-aware) |
| meta        | Test infra self-tests: sintaxe dos suites, exit codes, help flag, cleanup de sockets (detecta leak), funções entry point existem |

**Isolamento garantido** pelo socket name `claude-test-$$` (PID). Integration suite nunca toca nas sessões reais do usuário. **`cleanup_integration()` remove o socket file** além de `kill-server` — `kill-server` sozinho deixa o socket pendurado no filesystem.

### Adicionando testes ao mexer no conf

- Mudou um binding? → `test_bind_X` em `integration.sh` + `test_X` em `shell.sh`
- Corrigiu um bug de typo? → `test_no_X_typo` em `shell.sh` (regressão permanente)
- Adicionou plugin? → `test_plugins_listed` (shell), `test_var_*` se tiver `@var` (integration), **atualize `test_plugin_count_exact` em `structure.sh`** (hoje é 9)
- Mudou ordem de linhas críticas? → `structure.sh` tem assertions de line-order (TPM last run, Post-TPM após TPM)
- Alterou test harness? → `meta.sh` valida sintaxe, exit codes, cleanup

## Plugins — gerenciamento

- **Manager:** TPM em `~/.config/tmux/plugins/tpm/`, path definido por `TMUX_PLUGIN_MANAGER_PATH`
- **Install:** `prefix + I` (clona novos plugins listados)
- **Update:** `prefix + U`
- **Remove:** `prefix + alt+u` (depois de remover do conf)

### Plugins ativos e dependências de sistema

| Plugin | Deps sistema (macOS) | Binding padrão |
|--------|----------------------|----------------|
| tmux-sensible | nenhuma | — |
| tmux-resurrect | nenhuma | `prefix + C-s` (save), `prefix + C-r` (restore) |
| tmux-continuum | nenhuma (auto) | — |
| tmux-yank | `pbcopy` (nativo) | `y` em copy-mode |
| tmux-open | nenhuma | `o`/`C-o` em copy-mode |
| vim-tmux-navigator | precisa do plugin vim correspondente | `C-h/j/k/l` sem prefix |
| extrakto | `brew install fzf` | `prefix + Tab` |
| tmux-sessionx | `brew install fzf` (obrigatório); `bat`, `fd`, `zoxide` (opcional) | `prefix + O` |

### Lado Vim do vim-tmux-navigator

O usuário desta config usa **amix/vimrc + Pathogen** (plugins em `~/.vim_runtime/my_plugins/`). Para instalar nesse setup:
```bash
cd ~/.vim_runtime/my_plugins
git clone https://github.com/christoomey/vim-tmux-navigator.git
```
Para outros gerenciadores (vim-plug, lazy.nvim, etc.), adapte o caminho. O plugin adiciona `<C-h/j/k/l>` maps no Vim que conversam via `tmux send-keys` com o pane adjacente quando estão na borda.

## O que NÃO fazer

- ❌ Não reintroduzir `screen-256color` — usa `tmux-256color` + RGB override
- ❌ Não reintroduzir `bgbright=...` (atributo inválido) — use `bg=brightX`
- ❌ Não usar `#[bg=]` com valor vazio — use `#[bg=default]` pra resetar
- ❌ Não adicionar `set -g monitor-activity on` — tá `off` propositalmente (evita ruído)
- ❌ Não re-binde `C-h/j/k/l` globalmente — quebra o vim-tmux-navigator
- ❌ Não remover `bind C-l send-keys 'C-l'` — é o único caminho pro clear com vim-tmux-nav ativo
- ❌ Não remover `set -g status-keys vi` do **fim** do arquivo — a posição importa (post-TPM override)
- ❌ Não commitar sem rodar `bash test/run.sh` — a suite pega regressões dos bugs já corrigidos
- ❌ Não usar splits `v`/`s` — migrados pra `|`/`-`
- ❌ Não criar bindings que conflitam com: `prefix + c/C/G/T/O/r/h/j/k/l/|/-/H/J/K/L/C-l/</>` 

## Armadilhas conhecidas

- **`allow-rename off` + `automatic-rename on`**: o primeiro bloqueia apps (shell/vim) de renomear via escape seq; o segundo permite o tmux renomear baseado no comando atual. Os dois coexistem bem — se remover `automatic-rename on`, janelas nomeadas pelo usuário via `prefix + ,` param de atualizar dinamicamente, o que geralmente é desejado.
- **Undercurl** exige terminal compatível (WezTerm, Kitty, iTerm2 3.5+, Alacritty). Terminal.app não renderiza — as sequences vão ser ignoradas, não quebra.
- **`aggressive-resize on`** só afeta quando múltiplos clientes attach na mesma sessão. Geralmente um só client por sessão — option é idle mas gratuita.
- **Continuum + Resurrect**: o auto-save a cada 15min salva em `~/.config/tmux/plugins/tmux-resurrect/resurrect/`. Se apagar isso, perde histórico de sessões. `@continuum-restore 'on'` faz restore automático no primeiro attach após boot — útil mas pode surpreender.
- **Popup Claude/lazygit**: `-E` fecha popup quando o processo sai. Sem `-E`, o popup vira shell órfão.

## Padrões de edição

- **Adicionar binding:** topo do arquivo (seção KEY BINDINGS)
- **Adicionar cor/visual:** seção DESIGN CHANGES
- **Adicionar plugin:** entre o último `@plugin` e a linha de `run`, + `@vars` de config logo abaixo
- **Override de plugin default:** depois da linha `run '...'` do TPM

## Espelho público — SINCRONIZAR SEMPRE

Esta config vive em dois lugares: aqui (dentro do monorepo **privado** `~/.dotfiles`, que não é publicável) e no espelho público `github.com/albertosca/tmux`, que é um repositório separado com histórico reescrito por `git filter-repo`.

**Toda mudança em qualquer arquivo publicável tem que ser sincronizada:**

```bash
bash scripts/sync-public.sh            # roda a suite + shellcheck e publica
bash scripts/sync-public.sh --check    # só reporta drift (exit 1 = drifted)
```

- O script **recusa publicar no vermelho** — suite ou shellcheck falhando aborta antes do push.
- `PUBLISHED` no topo do script é um **allowlist**: arquivo que não está lá nunca chega no público. É a fronteira de privacidade — três testes em `structure.sh` conferem que a lista cobre o checkout e que nada privado entrou nela.
- `.public-sync` guarda o fingerprint do último estado publicado. Um hook `SessionStart` (`tmux-public-sync-nudge.py`) compara e avisa quando drifta — sem bloquear, e sem rede.
- **Nunca** use `git subtree push`: o `filter-repo` inicial faz ele recriar SHAs a cada run e exigir force push.
- Publicar é ação voltada pra fora — **confirme com o Alberto antes do push**.

**Por que isso existe:** entre junho e 20/08/2026 três commits ficaram só no privado e ninguém percebeu, porque o passo manual não tinha nada apontando pra ele.

### Remover num commit seguinte NÃO tira do repo público

Publicado é publicado. Apagar uma linha e commitar por cima deixa o conteúdo **acessível pra sempre** no commit pai — `git show <commit>^:arquivo` devolve ele inteiro. Auditado em 20/08/2026: duas "remoções" deste repo são cosméticas (o prompt pessoal tirado em junho e uma frase minha tirada no mesmo dia da auditoria); as duas seguem públicas. Nos dois casos o conteúdo é inofensivo, então ficou como está.

A consequência prática é para o futuro: **decida antes de publicar, não depois.** Se algo sensível de verdade escapar, o commit de remoção não resolve — só reescrita de histórico (`git filter-repo`) mais force push resolve, e isso exige decisão do Alberto.

## Nada de path absoluto sem guard

O conf é publicado como está e clonado por outras pessoas. Um caminho absoluto que não existe na máquina do outro **mata todo pane com exit 127** — medido: sem o guard, o servidor tmux inteiro não sobrevive ao boot. Todo alcance pra fora do repo fica atrás de uma checagem de existência:

- `default-command` → `if-shell '[ -x /opt/homebrew/bin/reattach-to-user-namespace ]'`
- `prefix + m` → `test -f ~/.claude/hooks/tmux-pending.sh && ... || true`

Ao adicionar qualquer binding que chame binário ou script de fora, guarde do mesmo jeito e escreva o teste correspondente em `shell.sh`.

## Commits / handoff entre IAs

Se você é uma IA lendo isso pra mexer no conf:
1. Rode `bash test/run.sh` ANTES de mudar qualquer coisa (baseline verde)
2. Faça mudança
3. Rode `bash test/run.sh` de novo — deve continuar verde
4. Rode `shellcheck -S warning scripts/*.sh test/*.sh` — o CI reprova warning
5. Se uma regressão foi pega, corrija antes de declarar feito
6. Se uma mudança legítima quebra um teste (ex: renomeou binding), atualize o teste correspondente
7. **Sincronize o espelho público** (seção acima) — commit no dotfiles não publica nada sozinho

O CHEATSHEET.md é para o **usuário** operar o tmux. Este CLAUDE.md é para **você** não quebrar nada.
