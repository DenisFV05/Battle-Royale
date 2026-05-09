import os
from PIL import Image

def leer_imagenes(directorio):
    extensiones_validas = (".png", ".jpg", ".jpeg", ".webp", ".bmp")

    for archivo in os.listdir(directorio):
        if archivo.lower().endswith(extensiones_validas):
            ruta = os.path.join(directorio, archivo)

            try:
                with Image.open(ruta) as img:
                    ancho, alto = img.size
                    print(f"{archivo} -> {ancho}x{alto}px")
            except Exception as e:
                print(f"Error con {archivo}: {e}")


# -------- CARPETAS --------
base = "Flutter\\assets\\levels\\media"

carpetas = [
    "misdreavous",
    "axew",
    "buizel",
    "chimchar",
    "pikachu",
    "riolu",
    "rockruff",
    "rowlet",
    "snorunt",
    "trapinch"
]

# -------- EJECUCIÓN --------
for carpeta in carpetas:
    print(f"\n--- {carpeta.upper()} ---")
    ruta_completa = os.path.join(base, carpeta)
    leer_imagenes(ruta_completa)