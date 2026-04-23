# tmux config

Config do tmux migrada pro caminho XDG (`~/.config/tmux/`). tmux 3.1+ carrega `tmux.conf` daqui automaticamente — não precisa de `~/.tmux.conf` nem symlink.

## Estrutura

```
~/.config/tmux/
├── tmux.conf      # config principal
├── README.md      # este arquivo
└── plugins/       # TMUX_PLUGIN_MANAGER_PATH aponta pra cá
    ├── tpm/
    ├── tmux-sensible/
    ├── tmux-resurrect/
    ├── tmux-yank/
    └── tmux-open/
```

## `tmux.conf` — seções

| Seção          | Destaques                                                                        |
|----------------|----------------------------------------------------------------------------------|
| KEY BINDINGS   | prefix `C-a`, splits `\|`/`-`, nav vim `hjkl`, resize `HJKL`, `r` = reload       |
| DESIGN CHANGES | cores de pane, status bar com data/hora, `mode-keys vi`, `mouse on`, true color  |
| PLUGINS        | tpm auto-install, 5 plugins + tpm, `run` do tpm na última linha                  |

## Plugins

- **tpm** — gerenciador
- **tmux-sensible** — defaults razoáveis
- **tmux-resurrect** — salva/restaura sessões (estratégia vim: session)
- **tmux-continuum** — auto-save a cada 15min + restore automático no boot
- **tmux-yank** — copiar pro clipboard (shell_mode vi)
- **tmux-open** — abrir seleção (`C-o` = abrir, `o` = editor)
- **vim-tmux-navigator** — navegação seamless `C-hjkl` entre Vim e tmux
- **extrakto** — `prefix + Tab` pra fuzzy-pescar paths/urls/hashes do pane
- **tmux-sessionx** — `prefix + O` pra fuzzy session switcher com preview

Instalar/atualizar: `prefix + I` (install), `prefix + U` (update).

Primeira vez após update de plugins: rode `prefix + I` pra TPM baixar os novos.

## Operação

Ver [`CHEATSHEET.md`](CHEATSHEET.md) — atalhos, popups, fluxos com extrakto/sessionx, como instalar `vim-tmux-navigator` no lado do Vim.

## Testes

```bash
bash test/run.sh              # tudo (4 suites), compacto
bash test/run.sh -v           # caso-a-caso
bash test/run.sh shell        # grep estático + regressões + ranges
bash test/run.sh structure    # line-order, duplicatas, encoding, plugin health
bash test/run.sh integration  # runtime em socket isolado
bash test/run.sh meta         # self-tests do test harness
```

Suite atual: **196 testes passing**. Cobre regressões de bugs corrigidos, options/bindings críticos, invariantes estruturais (TPM last run, Post-TPM override order), encoding, duplicate detection, socket cleanup. Rode antes de commitar. Para IAs mexendo no conf: ver [`CLAUDE.md`](CLAUDE.md).

## Diretórios antigos (não usados)

- `~/.tmux/` — clone do oh-my-tmux de 2019.
- `~/.tmux-plugins/tmux-powerline/` — plugin órfão de 2021.

Ambos podem ser removidos quando você quiser — a config atual não depende deles.
