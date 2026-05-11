# Pokemon Royale - Proyecto Multijugador

## Descripcion del Proyecto
Este proyecto es un videojuego de genero Battle Royale multijugador en tiempo real. El sistema permite la conexion de multiples jugadores simultaneos en un entorno compartido donde el objetivo es ser el ultimo superviviente. La arquitectura se basa en un modelo cliente-servidor para garantizar la sincronizacion de todos los elementos de la partida.

## Arquitectura del Sistema
El sistema esta dividido en dos componentes principales:

1. Servidor (Node.js): Gestiona la logica central, el estado de la partida, las colisiones y la comunicacion entre clientes. Utiliza WebSockets para una transmision de datos de baja latencia.
2. Cliente (Flutter): Proporciona la interfaz de usuario, el renderizado de graficos mediante Canvas y la gestion de entrada del teclado.

## Manual de Instalacion y Ejecucion

### Requisitos Previos
- Node.js instalado en el sistema.
- Flutter SDK configurado correctamente.
- Conexion a la misma red local para pruebas multijugador.

### Ejecucion del Servidor
1. Navegar a la carpeta Node/server.
2. Ejecutar el comando: npm install (solo la primera vez).
3. Ejecutar el comando: node index.js.
El servidor comenzara a escuchar conexiones en el puerto 3000 por defecto.

### Ejecucion del Cliente
1. Navegar a la carpeta Flutter.
2. Ejecutar el comando: flutter pub get (para instalar dependencias como audioplayers).
3. Ejecutar el comando: flutter run.

## Manual de Usuario

### Controles
- Movimiento: Utilice las teclas W, A, S, D o las flechas de direccion para desplazar al personaje por el mapa.
- Disparo: Pulse la barra espaciadora para lanzar un ataque elemental en la direccion en la que se encuentra mirando el personaje.
- Reinicio: En la pantalla final, pulse el boton de reinicio para volver a la sala de espera.

### Mecanicas de Juego
1. Sala de Espera: Al conectar, el jugador puede elegir su Pokemon. Cuando el servidor detecta suficientes jugadores, comienza una cuenta atras.
2. Partida: Los jugadores aparecen en puntos aleatorios del mapa. La salud se muestra sobre el personaje. Si la salud llega a cero, el jugador queda eliminado.
3. Gemas de Vida: Aparecen objetos verdes por el mapa que restauran la salud al entrar en contacto con ellos.
4. Mapa: El entorno contiene obstaculos como casas, agua y piedras que bloquean el movimiento y los disparos.
5. Ganador: La partida finaliza cuando solo queda un jugador con vida o se acaba el tiempo.

## Detalles Tecnicos de Implementacion

### Comunicacion (Protocolo JSON)
El intercambio de datos se realiza mediante mensajes JSON:
- El cliente envia inputs de direccion y comandos de disparo.
- El servidor responde con snapshots del estado global (posiciones de jugadores, balas activas y clasificacion).

### Sistema de Colisiones
El servidor valida todas las colisiones de forma autoritaria. El archivo gameLogic.js contiene las coordenadas exactas de cada obstaculo. Esto evita que los clientes puedan modificar su posicion para atravesar paredes de forma no autorizada.

### Renderizado y Camara
- Tilemaps: El mapa se construye dinamicamente mediante capas de tiles de 16x16 pixeles definidas en archivos JSON.
- Camara: Se ha implementado un sistema de camara que sigue al jugador local, manteniendo su posicion centrada en el area de vision y limitando el desplazamiento a los bordes del mapa.

## Autores
- Denis Fernandez
- David Bargados
