import json

with open('animations_fixed.json', 'r', encoding='utf-8') as f:
    data = json.load(f)
ruta_an = r'c:\Users\David\Desktop\DENIS\Battle-Royale\Flutter\assets\levels\animations\animations.json'

# Las 4 direcciones faltantes para "Hurt" con sus frames y nombres lógicos
missing_dirs = [
    {'id_suffix': 'down_left', 'name_suffix': 'Up', 'start': 8, 'end': 9},
    {'id_suffix': 'down_right', 'name_suffix': 'Up-Left', 'start': 10, 'end': 11},
    {'id_suffix': 'up_left', 'name_suffix': 'Left', 'start': 12, 'end': 13},
    {'id_suffix': 'up_right', 'name_suffix': 'Down-Left', 'start': 14, 'end': 15}
]

# 1. Identificar todos los Pokémon que existen
pokemons = set()
for anim in data.get('animations', []):
    if anim.get('id', '').startswith('anim_') and anim.get('id', '').endswith('_hurt_down'):
        pokemon_name = anim['id'].split('_')[1]
        pokemons.add(pokemon_name)

# Excluimos a Buizel porque ya las tiene (con IDs anim_4 a anim_7)
if 'buizel' in pokemons:
    pokemons.remove('buizel')

# 2. Generar e inyectar las animaciones faltantes
for pkmn in pokemons:
    capitalized_pkmn = pkmn.capitalize()
    for d in missing_dirs:
        new_id = f"anim_{pkmn}_hurt_{d['id_suffix']}"
        
        # Evitar duplicados
        if not any(a.get('id') == new_id for a in data['animations']):
            new_anim = {
                "id": new_id,
                "name": f"{capitalized_pkmn}-Hurt-{d['name_suffix']}",
                "mediaFile": f"media/{pkmn}/Hurt-Anim.png",
                "startFrame": d['start'],
                "endFrame": d['end'],
                "fps": 8.0,
                "loop": False,
                "groupId": f"__group_{pkmn}",
                "anchorX": 0.5,
                "anchorY": 0.5,
                "anchorColor": "red",
                "hitBoxes": [],
                "frameRigs": [
                    { "frame": d['start'], "anchorX": 0.5, "anchorY": 0.5, "anchorColor": "red", "hitBoxes": [] },
                    { "frame": d['end'], "anchorX": 0.5, "anchorY": 0.5, "anchorColor": "red", "hitBoxes": [] }
                ]
            }
            data['animations'].append(new_anim)

# Guardar el resultado final
with open('animations_full.json', 'w', encoding='utf-8') as f:
    json.dump(data, f, indent=2)

print("¡Listo! Se ha creado animations_full.json con los hurt faltantes.")