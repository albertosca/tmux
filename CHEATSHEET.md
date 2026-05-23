# Cheatsheet — tmux

Prefix = **`C-a`** (Ctrl + A).

> Convenção: `prefix + x` = aperte `C-a`, solte, depois `x`. `C-x` = aperte os dois juntos.

---

## Primeiro uso (depois de atualizar o conf)

1. Recarregue: `prefix + r`
2. Instale plugins novos: `prefix + I` (maiúsculo) — TPM baixa tudo.
3. (Opcional) Atualize plugins existentes: `prefix + U`
4. Instale deps de sistema (macOS):
   ```bash
   brew install fzf lazygit bat fd
   ```
   - `fzf` — obrigatório pra `extrakto` e `sessionx`
   - `lazygit` — pro popup `prefix + G`
   - `bat` + `fd` — melhoram o preview do `sessionx`
5. **Vim side** (vim-tmux-navigator) — ver seção "Vim" no final.

---

## Sessões, janelas, panes

| Ação | Atalho |
|------|--------|
| Nova sessão | `tmux new -s nome` (shell) |
| Listar sessões | `prefix + s` (nativo) ou **`prefix + O`** (sessionx, fuzzy) |
| Destacar (detach) | `prefix + d` |
| Reanexar última | `tmux a` (shell) |
| Renomear janela | `prefix + ,` |
| Nova janela | `prefix + c` (abre no cwd atual) |
| Próxima / anterior | `prefix + n` / `prefix + p` ou `Shift-→` / `Shift-←` |
| Ir pra janela N | `prefix + N` (1–9) |
| Fechar janela/pane | `prefix + &` / `prefix + x` |
| Mover janela ←/→ | `prefix + <` / `prefix + >` (repetível) |
| Trocar janela N com M | `:swap-window -s N -t M` |

## Splits

| Ação | Atalho |
|------|--------|
| Split horizontal (lado a lado) | `prefix + \|` |
| Split vertical (em cima/embaixo) | `prefix + -` |
| Zoom pane (toggle fullscreen) | `prefix + z` |
| Rotacionar panes | `prefix + space` |

## Navegar entre panes

| Ação | Atalho |
|------|--------|
| **Vim-aware (novo!)** | `C-h` / `C-j` / `C-k` / `C-l` — funciona dentro do Vim também |
| Com prefix | `prefix + h/j/k/l` |
| Alt-seta | `M-←/→/↑/↓` |

> `C-l` não limpa mais a tela direto — use `prefix + C-l` pra `clear`.

## Resize

| Ação | Atalho |
|------|--------|
| Resize 5 células | `prefix + H/J/K/L` (maiúsculo, repetível) |

---

## Popups flutuantes 🪟

| Ação | Atalho |
|------|--------|
| **Claude** | `prefix + C` — abre Claude Code num popup 85% |
| **Lazygit** | `prefix + G` — git TUI num popup 90% |
| **Shell scratch** | `prefix + T` — shell temporário 80% (escape/exit fecha) |

Todos abrem no `$PWD` do pane atual.

---

## Copy-mode (selecionar e copiar texto)

1. Entrar em copy-mode: `prefix + [`
2. Navegar: `hjkl`, `w`, `b`, `/` (search forward), `?` (backward), `n` / `N`
3. Selecionar: `v` (char), `C-v` (bloco retangular)
4. Copiar pro clipboard do macOS: `y`
5. Sair: `q`

Colar no tmux: `prefix + ]`. No macOS normal: `Cmd+V`.

---

## Extrakto — pesca paths/urls/hashes do terminal 🎣

`prefix + Tab` → abre fzf com tudo que tá visível no pane: paths, urls, hashes git, IPs, etc.

| Tecla dentro do extrakto | Ação |
|--------------------------|------|
| `Enter` | copia pro clipboard |
| `Tab` | insere no command-line do pane |
| `C-o` | abre com app padrão (via tmux-open) |
| `C-e` | abre no editor |
| `C-f` | alterna filtro (word / path / url / quote / s) |

**Caso de uso Phoenix/Rails:** erro cuspiu `lib/myapp/user.ex:42`? `prefix + Tab`, digita "user", `Tab` → path já tá no seu command-line pronto pro `vim`.

---

## Sessionx — fuzzy session switcher 🗂️

`prefix + O` (maiúsculo) → popup com fuzzy-search de sessões + preview.

| Tecla | Ação |
|-------|------|
| `Enter` | trocar pra sessão |
| `C-x` | matar sessão |
| `C-n` | nova sessão (digita nome) |
| `C-w` | ver/pular entre windows da sessão |
| `?` | help completo |

Com `zoxide` instalado, ele também sugere diretórios recentes — `Enter` num diretório cria sessão lá.

---

## Vim ↔ tmux (vim-tmux-navigator)

Instale o plugin no Vim. Você usa **amix/vimrc** com Pathogen, então:

```bash
cd ~/.vim_runtime/my_plugins
git clone https://github.com/christoomey/vim-tmux-navigator.git
```

Depois abra o Vim e rode `:Helptags` (ou reinicie). Pronto.

**Resultado:** `C-h/j/k/l` navega transparentemente entre splits do Vim e panes do tmux. Sem mudança mental, sem prefix.

> Prompt pra colar na outra janela do Claude:
> *"Instala o plugin christoomey/vim-tmux-navigator no meu setup Vim (amix/vimrc + Pathogen, plugins em ~/.vim_runtime/my_plugins/). Depois me confirma que tá funcionando listando os mappings que ele registra."*

---

## Resurrect + Continuum (sessões persistentes)

- **Auto-save**: continuum salva a cada 15min. Transparente.
- **Save manual**: `prefix + C-s`
- **Restore manual**: `prefix + C-r`
- Sessões sobrevivem a reboot da máquina (continuum restaura no primeiro `tmux` após boot).

---

## Outros plugins já instalados

### tmux-yank
Em copy-mode: `y` copia pro clipboard do sistema (já configurado acima).

### tmux-open
Seleciona URL/arquivo em copy-mode e:
- `o` — abre no editor
- `C-o` — abre com app padrão (`open` no macOS)

### tmux-sensible
Defaults razoáveis (escape-time, repeat-time, terminal overrides). Roda silencioso.

---

## Cola rápida — "Como eu faço X?"

| Quero… | Faço |
|--------|------|
| Abrir o Claude rápido | `prefix + C` |
| Pular de projeto | `prefix + O` |
| Pegar o path do erro que acabou de passar | `prefix + Tab` |
| Rodar git commit interativo | `prefix + G` |
| Abrir shell descartável | `prefix + T` |
| Recarregar config depois de editar | `prefix + r` |
| Limpar a tela (após vim-tmux-nav) | `prefix + C-l` |
| Ver sessões no modo antigo | `prefix + s` |
| Copiar output que subiu demais | `prefix + [`, navega, `v`, seleciona, `y` |

---

## Temas por sessão (trabalho / pessoal)

A barra de status e as bordas de pane mudam de cor automaticamente com base no **nome da sessão**:

| Nome começa com | Cor | Caso de uso |
|-----------------|-----|-------------|
| `work` | Ciano | Sessões de trabalho |
| `personal` | Laranja | Sessões pessoais |
| Qualquer outro | Padrão (preto) | — |

### Como criar uma sessão temática

No shell:
```bash
tmux new-session -s work            # ciano
tmux new-session -s work-myproject    # também ciano — prefixo que importa
tmux new-session -s personal        # laranja
tmux new-session -s personal-oss    # também laranja
```

De dentro do tmux:
```
prefix + :  →  new-session -s work-projeto
```

### Como mudar o tema de uma sessão existente

Renomeie — o hook dispara e aplica a nova cor na hora:

```
prefix + $   →  digita o novo nome (ex: work-myproject)
```

Ou pelo shell:
```bash
tmux rename-session -t nome-atual work-myproject
```

### Como funciona

O script `scripts/session-theme.sh` é chamado por três hooks:

- `session-created` — sessão nova recebe cor baseada no nome
- `client-session-changed` — ao trocar de sessão (`prefix + O`, `prefix + s`, attach), a barra muda
- `session-renamed` — renomear uma sessão dispara a re-coloração

As cores são definidas **no nível da sessão** (não global), então sessões work e personal podem estar abertas ao mesmo tempo, cada uma com sua cor.

---

## Troubleshooting

**"Plugin X não tá funcionando"** → Abra uma nova sessão tmux ou `prefix + I` de novo.

**Cores quebradas no Vim** → Verifique que seu terminal emula true color:
```bash
echo $TERM  # Deve ser xterm-256color ou similar FORA do tmux
```
Dentro do tmux deve aparecer `tmux-256color`.

**Undercurl não aparece** → Seu emulador precisa suportar (WezTerm, Kitty, iTerm2 3.5+, Alacritty). Terminal.app não suporta.

**`prefix + G` diz "command not found"** → `brew install lazygit`.

**`prefix + Tab` não abre nada** → `brew install fzf`.
