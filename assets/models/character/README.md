# Personagem 3D — AXEV CRIME
## Quaternius Universal Base Characters + Universal Animation Library 1

---

## Licença
Todos os assets são **CC0 (domínio público)**.
Uso livre em projectos pessoais, educacionais e comerciais.
Sem necessidade de atribuição.

---

## Ficheiros necessários (descarregar manualmente)

### 1. Personagem — Universal Base Characters
**URL:** https://quaternius.com/packs/universalbasecharacters.html
Ou Itch.io: https://quaternius.itch.io/universal-base-characters

Versão a descarregar: **Standard (gratuita)**

Do ZIP, extrai o ficheiro GLB do personagem masculino regular:
```
UniversalBaseCharacters[Standard]/
  └── Godot/            ← ou GLB/
      └── Male_Regular.glb   ← este ficheiro
```
Renomeia para: **`character.glb`**
Coloca em: `assets/models/character/character.glb`

### 2. Animações — Universal Animation Library 1
**URL:** https://quaternius.com/packs/universalanimationlibrary.html
Ou Itch.io: https://quaternius.itch.io/universal-animation-library

Versão a descarregar: **Standard (gratuita)**

Do ZIP, extrai o GLB de animações (não root motion):
```
UniversalAnimationLibrary[Standard]/
  └── Godot/            ← ou GLB/
      └── AnimationLibrary_Godot_Standard.glb  ← este ficheiro
```
Renomeia para: **`animations.glb`**
Coloca em: `assets/models/character/animations.glb`

---

## Integração em Godot 4.3 — passo a passo

### Passo 1 — Importar `character.glb`

1. Abre o projecto em Godot 4.3
2. No **FileSystem**, navega até `assets/models/character/`
3. Clica com o botão direito em `character.glb` → **Reimport**
4. Na aba **Import** (painel à direita):
   - `Meshes / Lightmap UV` → Off
   - `Skins / Use Named Skins` → On
   - **`Skeletons / Bone Renaming`** → On ← **crítico para retargeting**
   - `Animation / Import` → Off (este GLB não tem animações)
5. Clica **Reimport**

### Passo 2 — Importar `animations.glb`

1. Clica com o botão direito em `animations.glb` → **Reimport**
2. Na aba **Import**:
   - `Meshes / Import` → Off (não precisamos do mesh de placeholder)
   - **`Skeletons / Bone Renaming`** → On ← **crítico**
   - **`Animation / Import`** → On
   - `Animation / Storage` → `Files (.tres)` ← guarda as animações em disco
   - `Animation / Trimming` → On (remove frames vazios)
3. Clica **Reimport**

### Passo 3 — Montar na cena do Player

1. Abre `scenes/player.tscn`
2. No SceneTree, clica em **`CharacterMesh`**
3. No FileSystem, arrasta `character.glb` → solta sobre `CharacterMesh`
   - Um nó filho aparece (ex: `Male_Regular` ou `character`)
4. No SceneTree, clica em **`AnimationRoot`**
5. No FileSystem, arrasta `animations.glb` → solta sobre `AnimationRoot`
   - Um nó filho aparece com o AnimationPlayer

### Passo 4 — Ajustar escala do personagem

Selecciona o nó raiz do `character.glb` (filho de `CharacterMesh`):
- Se o personagem tiver ~1.8m → escala `(1, 1, 1)` ✓
- Se gigante (pack em centímetros) → escala `(0.01, 0.01, 0.01)`

Referência visual: o `CollisionShape3D` tem height=1.8m.
O personagem deve alinhar com a cápsula de colisão.

**Transform.origin.y do nó do personagem:**
- Se o personagem flutua → ajusta para negativo (ex: -0.9)
- Se está enterrado → ajusta para positivo

### Passo 5 — Verificar animações

Expande o nó filho de `AnimationRoot` → clica em **AnimationPlayer**.
No painel inferior (Animation), confirma que existem estas animações:
- `Idle`
- `Walk`
- `Jog`
- `Sprint`
- `Jump`
- `Fall`
- `Land`

Se os nomes tiverem prefixo `Armature|` (ex: `Armature|Idle`), o script
trata automaticamente — não precisas de mudar nada.

### Passo 6 — Testar

Prima **F5** (Play) ou **F6** (Play cena actual).
Usa WASD + rato para mover.
Verifica no Output se aparecem mensagens de erro do PlayerController.

---

## Estrutura final esperada em `player.tscn`

```
Player (CharacterBody3D)
├── CollisionShape3D              — colisão, NÃO mexer
├── CharacterMesh (Node3D)        — pivot de rotação do modelo
│   └── Male_Regular (Node3D)     — raiz do character.glb
│       └── Skeleton3D            — esqueleto humanoid
│           ├── MeshInstance3D    — mesh visível (~13k triângulos)
│           └── [outros nós]
├── AnimationRoot (Node3D)        — invisible, só serve as animações
│   └── AnimationLibrary (Node3D) — raiz do animations.glb
│       └── AnimationPlayer       — detectado pelo player_controller.gd
├── CameraPivot (Node3D)
│   └── Camera3D
└── TouchUI (instância)
```

---

## Troubleshooting

| Problema | Causa | Solução |
|---|---|---|
| Personagem invisível | GLB não adicionado | Ver Passo 3 |
| Sem animações | AnimationPlayer não encontrado | Confirmar que animations.glb está em AnimationRoot |
| Personagem gigante | Pack em centímetros | Escala (0.01, 0.01, 0.01) no nó filho |
| Personagem enterrado | Origin Y errado | origin.y negativo no nó filho |
| Animações em câmara lenta | GLB exportado a 24fps | Rever import settings de FPS |
| Aviso "Animação X não encontrada" | Nome diferente | Ver lista no AnimationPlayer e ajustar constantes em player_controller.gd |
| Rotação errada ao andar | Forward axis do GLB oposto | Rotação Z=180° no CharacterMesh |

---

## Links oficiais

- Universal Base Characters: https://quaternius.com/packs/universalbasecharacters.html
- Universal Animation Library 1: https://quaternius.com/packs/universalanimationlibrary.html
- Universal Animation Library 2: https://quaternius.com/packs/universalanimationlibrary2.html
- Discord Quaternius: https://discord.gg/quaternius (para dúvidas sobre os assets)
