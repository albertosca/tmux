# tmux config

Config pessoal do tmux, migrada pro caminho XDG (`~/.config/tmux/`). tmux 3.1+ carrega `tmux.conf` daqui automaticamente — não precisa de `~/.tmux.conf` nem symlink.

Plugins gerenciados pelo [TPM](https://github.com/tmux-plugins/tpm), que se auto-instala na primeira carga.

---

## Requisitos

- **tmux ≥ 3.2** (popups flutuantes)
- **macOS** — clipboard usa `pbcopy` nativo. No Linux, troque por `xclip` / `xsel` nos bindings de copy-mode e em `@extrakto_clip_tool`.
- **Dependências via Homebrew** (obrigatórias/recomendadas):
  ```bash
  brew install fzf          # obrigatório: extrakto + sessionx
  brew install lazygit      # popup prefix+G
  brew install bat fd       # melhoram preview do sessionx (opcional)
  brew install zoxide       # sessionx sugere diretórios recentes (opcional)
  ```

---

## Instalação

```bash
# 1. Clone (ou copie) pra ~/.config/tmux
git clone <url-do-repo> ~/.config/tmux

# 2. Inicie o tmux — TPM se instala automaticamente e baixa os plugins
tmux
```

Na primeira inicialização, o `tmux.conf` detecta que o TPM não existe e clona + instala tudo. Se preferir forçar manualmente: `prefix + I`.

> **Nota:** a pasta `plugins/` é ignorada pelo git (`.gitignore`) — cada máquina instala via TPM.

---

## Estrutura

```
~/.config/tmux/
├── tmux.conf           # config principal
├── CHEATSHEET.md       # atalhos, popups, fluxos operacionais
├── scripts/
│   └── session-theme.sh  # cores da status bar por sessão (work/personal)
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

O script `scripts/session-theme.sh` é chamado por hooks (`session-created`, `session-renamed`, `client-session-changed`).

---

## Testes

```bash
bash test/run.sh              # tudo (4 suites), output compacto
bash test/run.sh -v           # caso-a-caso
bash test/run.sh shell        # grep estático + regressões
bash test/run.sh structure    # line-order, duplicatas, encoding, plugin health
bash test/run.sh integration  # runtime em socket isolado
bash test/run.sh meta         # self-tests do harness
```

Suite atual: **196 testes passing**. Rode antes de commitar. Para IAs mexendo no conf: ver [`CLAUDE.md`](CLAUDE.md).

---

## Vim side (vim-tmux-navigator)

Para a navegação `C-h/j/k/l` funcionar dentro do Vim também, instale o plugin correspondente — ver seção **Vim ↔ tmux** no [`CHEATSHEET.md`](CHEATSHEET.md).
