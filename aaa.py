import json
import os

def crear_frame_rigs(frames):
    return [{"frame": f, "anchorX": 0.5, "anchorY": 0.5, "anchorColor": "red", "hitBoxes": []} for f in frames]

def master_generator_v3(ruta_game_data, ruta_anim, nombre_pj, carpeta_pj, configuraciones):
    # 1. Cargar archivos
    with open(ruta_anim, 'r', encoding='utf-8') as f:
        anim_json = json.load(f)
    with open(ruta_game_data, 'r', encoding='utf-8') as f:
        game_json = json.load(f)

    grupo_id = f"__group_{nombre_pj.lower()}"

    for archivo, f_fila, tipo, ancho, alto in configuraciones:
        ruta_relativa = f"media/{carpeta_pj}/{archivo}"
        tipo = tipo.capitalize()
        
        # --- A. Actualizar mediaAssets en game_data.json ---
        # Registramos cada hoja con su tamaño propio
        if not any(m['fileName'] == ruta_relativa for m in game_json["mediaAssets"]):
            game_json["mediaAssets"].append({
                "name": f"{nombre_pj}-{tipo} Asset",
                "fileName": ruta_relativa,
                "mediaType": "spritesheet",
                "tileWidth": ancho,
                "tileHeight": alto,
                "selectionColorHex": "#FFCC00",
                "groupId": grupo_id
            })

        # --- B. Generar Animaciones en animations.json ---
        if tipo in ["Idle", "Walk", "Strike"]:
            dirs = ["Down", "Left", "Right", "Up", "Down Left", "Down Right", "Up Left", "Up Right"]
        elif tipo == "Faint":
            dirs = ["South", "South West", "West", "North West", "North", "North East", "East", "South East"]
        else:
            dirs = ["Down", "Left", "Right", "Up"]

        for i, d_name in enumerate(dirs):
            inicio = i * f_fila
            anim_id = f"anim_{nombre_pj.lower()}_{tipo.lower()}_{d_name.lower().replace(' ', '_')}"
            
            if not any(a['id'] == anim_id for a in anim_json["animations"]):
                anim_json["animations"].append({
                    "id": anim_id,
                    "name": f"{nombre_pj}-{tipo}-{d_name.replace(' ', '-')}",
                    "mediaFile": ruta_relativa,
                    "startFrame": inicio,
                    "endFrame": inicio + (f_fila - 1),
                    "fps": 10.0 if tipo == "Walk" else 8.0,
                    "loop": tipo in ["Idle", "Walk"],
                    "groupId": grupo_id,
                    "anchorX": 0.5,
                    "anchorY": 0.5,
                    "anchorColor": "red",
                    "hitBoxes": [],
                    "frameRigs": crear_frame_rigs(list(range(inicio, inicio + f_fila)))
                })

    # 2. Guardar cambios
    with open(ruta_anim, 'w', encoding='utf-8') as f:
        json.dump(anim_json, f, indent=2, ensure_ascii=False)
    with open(ruta_game_data, 'w', encoding='utf-8') as f:
        json.dump(game_json, f, indent=2, ensure_ascii=False)

# --- USO CON TAMAÑOS DISTINTOS ---
# Formato: (Archivo, Frames_por_fila, Tipo, ANCHO, ALTO)
# --- CONFIGURACIÓN DE PRUEBA PARA AXEW ---
# Formato: (Archivo, Frames_por_fila, Tipo, ANCHO, ALTO)
# --- CONFIGURACIÓN MASIVA DE POKÉMON ---
# Formato: (Archivo, Frames_por_fila, Tipo, ANCHO, ALTO)
# --- CONFIGURACIÓN EXCLUSIVA PARA AXEW ---
# Formato: (Archivo, Frames_por_fila, Tipo, ANCHO, ALTO)
# --- CONFIGURACIÓN EXCLUSIVA PARA AXEW ---
# Formato: (Archivo, Frames_por_fila, Tipo, ANCHO, ALTO)

hojas_axew = [
    ("Idle-Anim.png", 4, "Idle", 32, 40),    # Tamaño estándar Axew
    ("Walk-Anim.png", 4, "Walk", 32, 40),    # Tamaño estándar Axew
    ("Strike-Anim.png", 6, "Strike", 64, 72), # Hoja de ataque (más grande)
    ("Faint-Anim.png", 4, "Faint", 40, 40),   # Hoja de debilitado
    ("Hurt-Anim.png", 2, "Hurt", 48, 56)      # Hoja de daño
]

# Rutas a tus archivos locales en Windows
ruta_gd = r'c:\Users\David\Desktop\DENIS\Battle-Royale\Flutter\assets\levels\game_data.json'
ruta_an = r'c:\Users\David\Desktop\DENIS\Battle-Royale\Flutter\assets\levels\animations\animations.json'

# Ejecutar el generador solo para Axew
# Nota: "axew" es el nombre de la carpeta donde están las imágenes
master_generator_v3(ruta_gd, ruta_an, "Axew", "axew", hojas_axew)

print("¡Procesado completo! Se han actualizado 'game_data.json' y 'animations.json' solo con los datos de Axew.")