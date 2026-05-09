import json

# El mapeo lógico de Buizel
direction_map = {
    'down': 'Down',             'south': 'Down',
    'left': 'Down-Right',       'south_west': 'Down-Right',
    'right': 'Right',           'west': 'Right',
    'up': 'Up-Right',           'north_west': 'Up-Right',
    'down_left': 'Up',          'north': 'Up',
    'down_right': 'Up-Left',    'north_east': 'Up-Left',
    'up_left': 'Left',          'east': 'Left',
    'up_right': 'Down-Left',    'south_east': 'Down-Left'
}

ruta_an = r'c:\Users\David\Desktop\DENIS\Battle-Royale\Flutter\assets\levels\animations\animations.json'


with open(ruta_an, 'r', encoding='utf-8') as f:
    data = json.load(f)

for anim in data.get('animations', []):
    anim_id = anim.get('id', '')
    
    # Omitir IDs generales como anim_1, anim_2, etc.
    if not anim_id.startswith('anim_') or sum(1 for c in anim_id if c == '_') < 3:
        continue

    parts = anim_id.split('_')
    pokemon = parts[1].capitalize()
    action = parts[2].capitalize()
    dir_key = '_'.join(parts[3:])

    if dir_key in direction_map:
        anim['name'] = f"{pokemon}-{action}-{direction_map[dir_key]}"

with open('animations_fixed.json', 'w', encoding='utf-8') as f:
    json.dump(data, f, indent=2)

print("¡Listo! Se ha creado el archivo animations_fixed.json")