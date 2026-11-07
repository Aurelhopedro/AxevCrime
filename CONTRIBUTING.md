# AXEV CRIME — Guia de Contribuição e Setup

## Requisitos

- Godot 4.3 (renderer: `gl_compatibility`, Mobile)
- Android SDK + NDK (para build APK)
- Assets Quaternius CC0 (ver abaixo)

---

## Assets Quaternius (CC0) — OBRIGATÓRIOS

Antes de abrir o projecto em Godot ou de correr o build Android,
coloca estes dois ficheiros em `assets/models/character/`:

| Ficheiro | Fonte | Nome original |
|---|---|---|
| `character.glb` | [Universal Base Characters](https://quaternius.com/packs/universalbasecharacters.html) | `Male_Regular.glb` (pasta Godot/ ou GLB/) |
| `animations.glb` | [Universal Animation Library 1](https://quaternius.com/packs/universalanimationlibrary.html) | `AnimationLibrary_Godot_Standard.glb` |

Ambos são **CC0 (domínio público)**, gratuitos, sem registo necessário.

**Instruções completas:** `assets/models/character/README.md`

---

## Integração em Godot 4.3

1. Coloca os GLBs em `assets/models/character/`
2. Abre o projecto em Godot 4.3
3. Importa ambos com `Bone Renaming` → On (ver README)
4. Abre `scenes/player.tscn`
5. Arrasta `character.glb` para o nó `CharacterMesh`
6. Arrasta `animations.glb` para o nó `AnimationRoot`
7. Ajusta escala do personagem se necessário (ver README)
8. Corre o projecto (F5)

---

## Build Android

O workflow `Build Android APK (Debug)` verifica automaticamente
se os GLBs estão presentes antes de compilar.

GitHub → Actions → "Build Android APK (Debug)" → Run workflow

---

## Estrutura do projecto

```
AxevCrime/
├── .github/workflows/
│   ├── build-android.yml          — build APK Android
│   ├── setup-character-model.yml  — helper para upload de GLBs
│   └── validate-godot.yml
├── assets/
│   ├── icon.svg
│   └── models/character/
│       ├── README.md              — integração Quaternius passo a passo
│       ├── character.glb          — NÃO incluído (CC0, descarregar)
│       └── animations.glb         — NÃO incluído (CC0, descarregar)
├── scenes/
│   ├── main.tscn                  — cena principal (spawna player)
│   ├── player.tscn                — CharacterBody3D + CharacterMesh + AnimationRoot
│   └── touch_ui.tscn              — joystick virtual + câmara + botões
├── scripts/
│   ├── main.gd
│   ├── player_controller.gd       — movimento + animações (Idle/Walk/Jog/Sprint/Jump/Fall/Land)
│   └── touch_controller.gd        — input touch (joystick, câmara, botões)
├── export_presets.cfg
└── project.godot                  — Godot 4.3, Mobile, gl_compatibility
```

---

## Animações suportadas (Universal Animation Library 1)

O `player_controller.gd` gere automaticamente estes estados:

| Estado | Animação | Trigger |
|---|---|---|
| Parado | `Idle` | velocidade < 0.3 m/s |
| A andar | `Walk` | input + sem run |
| A trotar | `Jog` | input + run + vel < 5.5 m/s |
| A correr | `Sprint` | input + run + vel ≥ 5.5 m/s |
| A saltar | `Jump` | velocidade.y > 0 no ar |
| A cair | `Fall` | velocidade.y < 0 no ar |
| Aterragem | `Land` | transição ar→chão (0.4s) |

Se os nomes no GLB tiverem prefixo `Armature|` (ex: `Armature|Idle`),
o script tenta automaticamente o prefixo.
