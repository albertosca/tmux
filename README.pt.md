# tmux config

- 🇺🇸 [English](README.md)
- 🇧🇷 [Português](README.pt.md)

[![CI](https://github.com/albertosca/tmux/actions/workflows/ci.yml/badge.svg)](https://github.com/albertosca/tmux/actions/workflows/ci.yml)
[![ShellCheck](https://github.com/albertosca/tmux/actions/workflows/lint.yml/badge.svg)](https://github.com/albertosca/tmux/actions/workflows/lint.yml)

Config pessoal do tmux, no caminho XDG (`~/.config/tmux/`). tmux 3.1+ carrega `tmux.conf` daqui automaticamente — não precisa de `~/.tmux.conf` nem symlink.

Plugins gerenciados pelo [TPM](https://github.com/tmux-plugins/tpm), que se auto-instala na primeira carga. A config vem com uma suite de testes que cobre o conf de forma estática, estrutural e em runtime.

---

## Requisitos

- **tmux ≥ 3.2** (popups flutuantes)
- **macOS** — clipboard usa `pbcopy` nativo. No Linux, troque por `xclip` / `xsel` nos bindings de copy-mode e em `@extrakto_clip_tool`.
- **Dependências via Homebrew:**
  ```bash
  brew install fzf          # obrigatório: extrakto + sessionx
  brew install lazygit      # popup prefix+G
  brew install bat fd       # melhoram preview do sessionx (opcional)
  brew install zoxide       # sessionx sugere diretórios recentes (opcional)
  ```

---

## Instalação

```bash
# 1. Clone pra ~/.config/tmux
git clone https://github.com/albertosca/tmux.git ~/.config/tmux

# 2. Inicie o tmux — TPM se instala automaticamente e baixa os plugins
tmux
```

Na primeira inicialização, o `tmux.conf` detecta que o TPM não existe e clona + instala tudo. Se preferir forçar manualmente: `prefix + I`.

> **Nota:** a pasta `plugins/` é ignorada pelo git — cada máquina instala via TPM.

---

## Estrutura

```
~/.config/tmux/
├── tmux.conf           # config principal
├── CHEATSHEET.md       # atalhos, popups, fluxos operacionais
├── scripts/
│   ├── session-theme.sh  # cores da status bar por sessão (work/personal)
│   └── sync-public.sh    # publica esta config no espelho público
├── test/
│   ├── run.sh          # entry point dos testes
│   ├── shell.sh        # checagens estáticas no conf
│   ├── integration.sh  # testes dinâmicos (socket isolado)
│   ├── structure.sh    # line-order, duplicatas, plugin health
│   ├── meta.sh         # self-tests do harness
│   └── lib.sh          # assertion helpers
└── plugins/            # gerenciado pelo TPM (não versionado)
    └── tpm/
```

---

## `tmux.conf` — seções

| Seção            | Destaques                                                                          |
|------------------|------------------------------------------------------------------------------------|
| KEY BINDINGS     | prefix `C-a`, splits `\|`/`-`, nav vim `hjkl`, resize `HJKL`, popups, `r` = reload |
| DESIGN CHANGES   | cores de pane, status bar com sessões + branch git + data/hora, true color        |
| PLUGINS          | TPM auto-install, 9 plugins, `run` do TPM na última linha                         |
| Post-TPM         | overrides que precisam vencer defaults do tmux-sensible (ex: `status-keys vi`)    |

A ordem de carga importa: o `tmux-sensible` seta `status-keys emacs` incondicionalmente quando carrega, então tudo que precisa vencê-lo fica **depois** da linha `run` do TPM.

---

## Plugins

| Plugin | Função | Binding |
|--------|--------|---------|
| [tpm](https://github.com/tmux-plugins/tpm) | gerenciador | `prefix+I` install, `prefix+U` update |
| [tmux-sensible](https://github.com/tmux-plugins/tmux-sensible) | defaults razoáveis | — |
| [tmux-resurrect](https://github.com/tmux-plugins/tmux-resurrect) | salva/restaura sessões | `prefix+C-s` / `prefix+C-r` |
| [tmux-continuum](https://github.com/tmux-plugins/tmux-continuum) | auto-save 15min + restore no boot | — |
| [tmux-yank](https://github.com/tmux-plugins/tmux-yank) | copia pro clipboard | `y` em copy-mode |
| [tmux-open](https://github.com/tmux-plugins/tmux-open) | abre seleção | `o` / `C-o` em copy-mode |
| [vim-tmux-navigator](https://github.com/christoomey/vim-tmux-navigator) | nav seamless Vim ↔ tmux | `C-h/j/k/l` sem prefix |
| [extrakto](https://github.com/laktak/extrakto) | fuzzy-grab de paths/urls/hashes | `prefix+Tab` |
| [tmux-sessionx](https://github.com/omerxx/tmux-sessionx) | fuzzy session/window switcher | `prefix+O` |

---

## Temas por sessão

A status bar e as bordas mudam de cor automaticamente pelo nome da sessão:

| Prefixo do nome | Cor    |
|-----------------|--------|
| `work`          | Ciano  |
| `personal`      | Laranja |
| qualquer outro  | Padrão (preto) |

O script `scripts/session-theme.sh` é chamado pelos hooks `session-created`, `session-renamed` e `client-session-changed`.

---

## Indicador de pendência

A aba de uma janela muda de cor sozinha enquanto um Claude Code naquela janela está esperando você, e dá pra marcar uma aba à mão pra voltar nela depois.

| Cor da aba | Significado |
|------------|-------------|
| Normal | nada pendente |
| **Violeta** | um Claude terminou, ou perguntou algo, e está esperando você |
| **Verde** | você marcou essa aba com `prefix + m` |

A marca manual tem precedência sobre a pendência e nunca a apaga: marcar uma aba violeta deixa ela verde, e desmarcar traz o violeta de volta se aquele Claude ainda estiver esperando. A pendência só sai quando você de fato responde — trocar de aba e ler não conta. A aba selecionada aparece num tom mais claro da cor que estiver valendo, em negrito.

Abas coloridas vizinhas se conectam no estilo powerline: a cunha entre duas delas leva a cor da aba anterior, e uma sequência de abas da mesma cor é dividida por um separador fino, em vez de um triângulo invisível da mesma cor sobre ela mesma.

> Essa metade mora fora deste repo, em `~/.claude/hooks/tmux-pending.sh`. Sem ele o `prefix + m` não faz nada — o binding é guardado por `test -f` — e todo o resto funciona normalmente.

---

## Testes

```bash
bash test/run.sh              # as 4 suites, output compacto
bash test/run.sh -v           # caso-a-caso
bash test/run.sh shell        # grep estático + regressões
bash test/run.sh structure    # line-order, duplicatas, encoding, plugin health
bash test/run.sh integration  # runtime em socket isolado
bash test/run.sh meta         # self-tests do harness
```

A suite de integração sobe um servidor tmux próprio num socket isolado por PID (`claude-test-$$`), então nunca toca nas sessões em uso. Rode antes de commitar — ela codifica como regressão permanente cada bug já corrigido aqui.

---

## Notas de portabilidade

Dois bindings alcançam coisas fora deste repositório e estão guardados para que um clone novo continue funcionando:

- O `default-command` fixa por caminho absoluto o `reattach-to-user-namespace` nativo arm64 (a versão Intel resolvida via PATH força silenciosamente todo pane sob Rosetta). O pin fica atrás de um `if-shell` que checa existência — sem guard, um caminho absoluto ausente mata todo pane com exit 127.
- O `prefix + m` chama um hook pessoal do Claude Code que só existe na minha máquina, atrás de um `test -f`, então em qualquer outro lugar ele é inofensivo.

---

## Lado Vim (vim-tmux-navigator)

Para a navegação `C-h/j/k/l` funcionar dentro do Vim também, instale o plugin correspondente — ver seção **Vim ↔ tmux** no [`CHEATSHEET.md`](CHEATSHEET.md).

---

## Projetos relacionados

- **[albertosca/vim-runtime](https://github.com/albertosca/vim-runtime)** — minha config do Vim (complementa este setup: navegação tmux↔Vim, plugins, tema)
