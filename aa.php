<?php
session_start();
include("conexion.php");

if(!isset($_SESSION['id_usuario'])){
    header("Location:index.php");
    exit();
}

$id = $_SESSION['id_usuario'];

$stmt = $conexion->prepare("SELECT saldo FROM usuarios WHERE id_usuario=?");
$stmt->bind_param("i",$id);
$stmt->execute();

$saldo = $stmt->get_result()->fetch_assoc()['saldo'];
?>

<!DOCTYPE html>
<html lang="es">
<head>

<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">

<title>Casino Live Blackjack</title>

<script src="https://cdn.tailwindcss.com"></script>

<style>

body{
    background:url("img/blackjack_table.jpg") center/cover no-repeat;
}

/* FLIP REAL */
.flip-card{
    perspective:1000px;
}

.flip-inner{
    position:relative;
    width:90px;
    height:130px;
    transform-style:preserve-3d;
    animation:flip .7s ease forwards;
}

.flip-front,
.flip-back{
    position:absolute;
    width:100%;
    height:100%;
    backface-visibility:hidden;
    border-radius:10px;
}

.flip-front{
    transform:rotateY(0deg);
}

.flip-back{
    transform:rotateY(180deg);
}

@keyframes flip{

    from{
        transform:rotateY(180deg) translateY(-40px);
        opacity:0;
    }

    to{
        transform:rotateY(0deg) translateY(0);
        opacity:1;
    }
}

/* DEALER DEAL */
.deal-anim{
    animation:deal .3s ease;
}

@keyframes deal{

    from{
        transform:translateY(-40px);
        opacity:0;
    }

    to{
        transform:translateY(0);
        opacity:1;
    }
}

/* DESKTOP */
@media(min-width:1024px){

    .flip-inner{
        width:110px;
        height:160px;
    }

}

/* MOBILE */
@media(max-width:768px){

    .flip-inner{
        width:65px;
        height:95px;
    }

}

</style>

</head>

<body class="overflow-hidden text-white">

<!-- OVERLAY -->
<div class="fixed inset-0 bg-black/60"></div>

<!-- HEADER -->
<header class="fixed top-0 left-0 w-full h-16 bg-black/60 backdrop-blur-md flex items-center justify-between px-4 z-50">

    <button onclick="goHome()"
        class="bg-black border border-white px-4 py-2 rounded-xl hover:bg-white hover:text-black transition">

        🏠 Principal

    </button>

    <div class="bg-yellow-400 text-black px-5 py-2 rounded-2xl font-black text-lg shadow-2xl">

        💰 <span id="saldoHeader"><?= number_format($saldo,2) ?></span>$

    </div>

</header>

<!-- ALERT -->
<div id="casinoAlert"
     class="hidden fixed top-20 left-1/2 -translate-x-1/2 z-[99999]
            bg-red-500 text-white px-6 py-3 rounded-2xl
            text-xl font-black shadow-2xl">
</div>

<!-- START SCREEN -->
<div id="startScreen"
     class="fixed inset-0 bg-black/95 z-[99999] flex items-center justify-center">

    <div class="bg-zinc-900 border border-white/10 rounded-3xl p-8 w-[90%] max-w-md text-center shadow-2xl">

        <h1 class="text-4xl font-black text-yellow-400 mb-5">
            CASINO LIVE
        </h1>

        <p class="text-zinc-400 mb-2">
            Saldo disponible:
        </p>

        <div class="text-3xl font-black mb-5">
            <?= number_format($saldo,2) ?>$
        </div>

        <input
            id="bankroll"
            type="number"
            placeholder="Dinero para la sesión"
            class="w-full bg-zinc-800 rounded-xl p-3 mb-4 text-white outline-none border border-zinc-700 focus:border-yellow-400"
        >

        <select
            id="time"
            class="w-full bg-zinc-800 rounded-xl p-3 mb-4 text-white border border-zinc-700">

            <option value="30">30 minutos</option>
            <option value="60">1 hora</option>
            <option value="120">2 horas</option>

        </select>

        <button
            onclick="startGame()"
            class="w-full bg-green-500 hover:bg-green-400 py-3 rounded-2xl text-xl font-black transition">

            COMENZAR

        </button>

        <p id="error" class="text-red-500 mt-3"></p>

    </div>

</div>

<!-- MESA -->
<main class="relative z-10 h-screen pt-20 flex items-center justify-center">

<div class="w-full max-w-7xl flex flex-col items-center gap-10 scale-100 lg:scale-110">

    <!-- DEALER -->
    <div class="text-center">

        <h2 class="text-3xl font-black mb-4">
            🃏 CRUPIER
        </h2>

        <div id="dealerCards"
             class="flex justify-center gap-3 min-h-[140px]">
        </div>

    </div>

    <!-- CENTRO -->
    <div class="flex flex-col items-center gap-5">

        <!-- RESULT -->
        <div id="gameResult"
             class="text-3xl font-black h-10">
        </div>

        <!-- BET ZONE -->
        <div id="dropZone"
             class="w-56 h-56 rounded-full border-4 border-dashed border-green-400 flex flex-col items-center justify-center text-center shadow-[0_0_40px_rgba(34,197,94,0.5)]">

            <div class="text-2xl font-black">
                APUESTA
            </div>

            <div class="text-5xl font-black text-yellow-400">
                <span id="bet">0</span>$
            </div>

        </div>

        <!-- CHIPS -->
        <div class="flex flex-wrap justify-center gap-3 max-w-4xl">

            <div draggable="true" data-value="0.5"
                class="chip bg-gray-200 text-black w-20 h-20 rounded-full flex items-center justify-center font-black text-xl cursor-grab shadow-2xl border-4 border-white">
                0.5
            </div>

            <div draggable="true" data-value="1"
                class="chip bg-white text-black w-20 h-20 rounded-full flex items-center justify-center font-black text-xl cursor-grab shadow-2xl border-4 border-gray-300">
                1
            </div>

            <div draggable="true" data-value="2"
                class="chip bg-yellow-300 text-black w-20 h-20 rounded-full flex items-center justify-center font-black text-xl cursor-grab shadow-2xl border-4 border-yellow-500">
                2
            </div>

            <div draggable="true" data-value="5"
                class="chip bg-green-500 w-20 h-20 rounded-full flex items-center justify-center font-black text-xl cursor-grab shadow-2xl border-4 border-green-300">
                5
            </div>

            <div draggable="true" data-value="10"
                class="chip bg-sky-400 w-20 h-20 rounded-full flex items-center justify-center font-black text-xl cursor-grab shadow-2xl border-4 border-sky-200">
                10
            </div>

            <div draggable="true" data-value="50"
                class="chip bg-pink-500 w-20 h-20 rounded-full flex items-center justify-center font-black text-xl cursor-grab shadow-2xl border-4 border-pink-200">
                50
            </div>

            <div draggable="true" data-value="100"
                class="chip bg-red-500 w-20 h-20 rounded-full flex items-center justify-center font-black text-xl cursor-grab shadow-2xl border-4 border-red-200">
                100
            </div>

        </div>

        <!-- BUTTON -->
        <button
            id="dealBtn"
            onclick="deal()"
            class="bg-blue-500 hover:bg-blue-400 px-8 py-3 rounded-2xl text-2xl font-black shadow-2xl transition">

            REPARTIR

        </button>

    </div>

    <!-- PLAYER -->
    <div class="text-center">

        <h2 class="text-3xl font-black mb-4">
            👤 JUGADOR
        </h2>

        <div id="playerCards"
             class="flex justify-center gap-3 min-h-[140px]">
        </div>

        <div class="flex justify-center gap-4 mt-5">

            <button
                onclick="hit()"
                class="bg-yellow-500 hover:bg-yellow-400 px-8 py-3 rounded-2xl text-2xl font-black">

                HIT

            </button>

            <button
                onclick="stand()"
                class="bg-red-500 hover:bg-red-400 px-8 py-3 rounded-2xl text-2xl font-black">

                STAND

            </button>

        </div>

    </div>

</div>

</main>

<script>

let saldo = <?= $saldo ?>;
let bankroll = 0;
let bet = 0;

let player = [];
let dealer = [];

let gameStarted = false;
let canDeal = true;

/* HOME */
function goHome(){

    saveSaldo();

    window.location.href="principal.php";
}

/* ALERT */
function showAlert(msg){

    let alertBox = document.getElementById("casinoAlert");

    alertBox.innerText = msg;

    alertBox.classList.remove("hidden");

    setTimeout(()=>{

        alertBox.classList.add("hidden");

    },2000);
}

/* SAVE */
function saveSaldo(){

    fetch("resultado_blackjack.php",{

        method:"POST",

        headers:{
            "Content-Type":"application/json"
        },

        body:JSON.stringify({
            saldo:saldo
        })

    });

}

/* START */
function startGame(){

    bankroll = parseFloat(
        document.getElementById("bankroll").value
    );

    if(isNaN(bankroll) || bankroll <= 0){

        document.getElementById("error").innerText =
            "Dinero inválido";

        return;
    }

    if(bankroll > saldo){

        document.getElementById("error").innerText =
            "Saldo no disponible";

        return;
    }

    gameStarted = true;

    document.getElementById("startScreen").style.display="none";
}

/* SALDO */
function updateSaldo(){

    document.getElementById("saldoHeader").innerText =
        saldo.toFixed(2);
}

/* DRAG */
document.querySelectorAll(".chip").forEach(chip=>{

    chip.addEventListener("dragstart",e=>{

        e.dataTransfer.setData(
            "value",
            chip.dataset.value
        );

    });

});

/* DROP */
const dropZone = document.getElementById("dropZone");

dropZone.addEventListener("dragover",e=>e.preventDefault());

dropZone.addEventListener("drop",e=>{

    e.preventDefault();

    if(!gameStarted) return;
    if(!canDeal) return;

    let value = parseFloat(
        e.dataTransfer.getData("value")
    );

    if(bet + value > saldo){

        showAlert("Saldo no disponible");

        return;
    }

    bet += value;

    document.getElementById("bet").innerText =
        bet.toFixed(2);

});

/* CARD */
function card(){

    let values = [
        "2","3","4","5","6","7",
        "8","9","10","J","Q","K","A"
    ];

    let suits = [
        "corazones",
        "diamantes",
        "trebol",
        "picas"
    ];

    return `${values[Math.floor(Math.random()*values.length)]}-${suits[Math.floor(Math.random()*suits.length)]}.png`;
}

/* CARD HTML */
function createCard(src){

    return `
        <div class="flip-card deal-anim">

            <div class="flip-inner">

                <img
                    src="img/cards/back.png"
                    class="flip-front object-cover"
                >

                <img
                    src="img/cards/${src}"
                    class="flip-back object-cover"
                >

            </div>

        </div>
    `;
}

/* RENDER */
function render(){

    document.getElementById("playerCards").innerHTML =
        player.map(c=>createCard(c)).join("");

    document.getElementById("dealerCards").innerHTML =
        dealer.map(c=>createCard(c)).join("");
}

/* DEAL */
function deal(){

    if(!canDeal) return;

    if(bet <= 0){

        showAlert("Debes apostar");

        return;
    }

    canDeal = false;

    player = [card(),card()];
    dealer = [card(),card()];

    render();

    saldo -= bet;

    updateSaldo();

    document.getElementById("dealBtn").disabled = true;
}

/* HIT */
function hit(){

    if(canDeal) return;

    player.push(card());

    render();

    if(player.length >= 5){

        finish(false);
    }

}

/* STAND */
function stand(){

    if(canDeal) return;

    while(dealer.length < 4){

        dealer.push(card());

    }

    finish(Math.random()>0.5);
}

/* FINISH */
function finish(win){

    let result = document.getElementById("gameResult");

    if(win){

        let won = bet * 2;

        saldo += won;

        result.innerHTML =
            `🎉 GANASTE ${won.toFixed(2)}$`;

        result.className =
            "text-3xl font-black text-green-400";

    }else{

        result.innerHTML =
            `💀 PERDISTE ${bet.toFixed(2)}$`;

        result.className =
            "text-3xl font-black text-red-500";
    }

    updateSaldo();

    saveSaldo();

    bet = 0;

    document.getElementById("bet").innerText = 0;

    canDeal = true;

    document.getElementById("dealBtn").disabled = false;
}

/* EXIT SAVE */
window.addEventListener("beforeunload",saveSaldo);

</script>

</body>
</html>