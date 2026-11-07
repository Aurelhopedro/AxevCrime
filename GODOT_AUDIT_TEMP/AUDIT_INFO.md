# GODOT_AUDIT_TEMP — Pasta de Auditoria

Esta pasta é gerada automaticamente pelo workflow
`.github/workflows/godot-audit-collect.yml` e destina-se
exclusivamente à análise do projecto Godot.

## Conteúdo

| Pasta / Ficheiro      | Origem                                        |
|-----------------------|-----------------------------------------------|
| `scenes/`             | Cenas originais do projecto (`.tscn`)         |
| `scripts/`            | Scripts originais do projecto (`.gd`)         |
| `assets/`             | Texturas e recursos filtrados                 |
| `build_web/`          | Ficheiros gerados pela exportação Web         |
| `logs/`               | Logs do processo de importação e exportação   |
| `project.godot`       | Configuração principal do projecto            |
| `export_presets.cfg`  | Configuração de exportação                    |

## Regras

- Esta pasta **não afecta** o funcionamento do jogo.
- Pode ser **apagada manualmente** sem qualquer consequência.
- Nenhum ficheiro original foi modificado.
- Nenhuma credencial ou token está incluído.

## Gerado em

Workflow executado manualmente via GitHub Actions.
