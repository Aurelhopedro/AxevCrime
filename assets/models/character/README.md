# Modelo do Personagem — AXEV CRIME

## Fonte
**Quaternius Ultimate Modular Characters**
https://quaternius.com/packs/ultimatemodularcharacters.html
Licença: **CC0 (domínio público)** — sem restrições de uso ou atribuição.

---

## Porquê esta pasta existe
O `player.tscn` tem um nó `CharacterMesh` pronto para receber o GLB.
O `player_controller.gd` detecta automaticamente o `AnimationPlayer` dentro do GLB.
O jogo funciona **sem o GLB** (personagem invisível mas totalmente controlável).

---

## Passos para integrar o GLB (uma vez, no Godot Editor)

### 1. Obter o GLB
- Vai a https://quaternius.com/packs/ultimatemodularcharacters.html
- Descarrega o pack (gratuito, CC0)
- Encontra um ficheiro `.glb` com animações (ex: `AnimatedCharacter.glb`)
- Renomeia para `character.glb` e coloca nesta pasta

### 2. Importar em Godot 4.3
1. Abre o projecto (`project.godot`) em Godot 4.3
2. No **FileSystem**, navega até `assets/models/character/`
3. Faz duplo clique em `character.glb` → aba **Import** aparece
4. Em **Import → Animation → Storage**: selecciona `Files` para guardar as animações
5. Clica **Reimport**

### 3. Montar na cena do Player
1. Abre `scenes/player.tscn`
2. No **SceneTree**, selecciona o nó `CharacterMesh`
3. No **FileSystem**, arrasta `character.glb` → solta em cima de `CharacterMesh`
4. O GLB aparece como filho de `CharacterMesh`

### 4. Ajustar escala (se necessário)
Selecciona o nó raiz do GLB importado:
- Se o personagem tiver ~180cm → escala `(1, 1, 1)` ✓
- Se gigante (pack em cm) → escala `(0.01, 0.01, 0.01)`
- Verifica com o `CollisionShape3D` como referência (height=1.8)

### 5. Verificar animações
Abre o **AnimationPlayer** do GLB e confirma que existem:
- `Idle` (ou `Armature|Idle`)
- `Walk` (ou `Armature|Walk`)
- `Run` (ou `Armature|Run`)
- `Jump` (ou `Armature|Jump`)

O script tenta automaticamente o prefixo `Armature|` se os nomes simples não existirem.

---

## Estrutura esperada em `player.tscn` após integração

```
Player (CharacterBody3D)
├── CollisionShape3D        ← colisão, NÃO mexer
├── CharacterMesh (Node3D)  ← pivot de rotação do modelo
│   └── character (Node3D)  ← raiz do GLB importado
│       ├── Skeleton3D
│       ├── MeshInstance3D  ← o mesh visível
│       └── AnimationPlayer ← detectado pelo player_controller.gd
├── CameraPivot (Node3D)
│   └── Camera3D
└── TouchUI (instância)
```

---

## Troubleshooting

| Problema | Solução |
|---|---|
| Personagem invisível | GLB não adicionado a `CharacterMesh` — ver passo 3 |
| Sem animações | Verificar nomes no AnimationPlayer — ver passo 5 |
| Personagem gigante | Escala `(0.01, 0.01, 0.01)` no nó raiz do GLB |
| Personagem enterrado no chão | Ajustar `transform.origin.y` do nó GLB para 0 |
| Personagem flutua | Ajustar `transform.origin.y` para negativo (ex: -0.9) |
| Aviso no log | Normal se GLB ausente — funciona sem o modelo |
