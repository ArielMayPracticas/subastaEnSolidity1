// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

contract SubastaAvanzadaConFee {
    address public subastador;   
    uint public ofertaBase;
    uint public ofertaMaxima;
    address public mejorPostor;
    bool public finalizada;

    uint public inicio;
    uint public fin;
    uint constant EXTENSION_TIEMPO = 10 minutes;
    uint constant INCREMENTO_MINIMO_PORCENTUAL = 5;
    uint constant FEE_PORCENTUAL = 2;

    uint public acumuladoPorSubastador; // Monto total acumulado de comisiones

    mapping(address => uint) public devoluciones;

    event NuevaOferta(address indexed postor, uint cantidad, uint nuevoFin);
    event SubastaFinalizada(address ganador, uint cantidad, uint totalComisiones);
    event RetiroConFee(address indexed postor, uint devuelto, uint feeCobrado);

    constructor() {
        subastador = msg.sender;
        ofertaBase = 2 ether;
        inicio = block.timestamp;
        fin = block.timestamp + 2 days;
    }

    function ofertar() external payable {
        require(block.timestamp >= inicio, "La subasta aun no comienza");
        require(block.timestamp <= fin, "La subasta ha finalizado");
        require(!finalizada, "La subasta ya fue finalizada");

        if (ofertaMaxima == 0) {
            require(msg.value >= ofertaBase, "La oferta es menor al minimo base (2 ETH)");
        } else {
            uint incrementoMinimo = (ofertaMaxima * (100 + INCREMENTO_MINIMO_PORCENTUAL)) / 100;
            require(msg.value >= incrementoMinimo, "Debe superar la oferta actual en al menos 5%");
        }

        if (ofertaMaxima > 0) {
            devoluciones[mejorPostor] += ofertaMaxima;
        }

        mejorPostor = msg.sender;
        ofertaMaxima = msg.value;

        if (fin - block.timestamp <= 10 minutes) {
            fin = block.timestamp + EXTENSION_TIEMPO;
        }

        emit NuevaOferta(msg.sender, msg.value, fin);
    }

    function retirar() external {
        uint monto = devoluciones[msg.sender];
        require(monto > 0, "Nada que retirar");

        // Calcular fee (2%) y saldo a devolver
        uint fee = (monto * FEE_PORCENTUAL) / 100;
        uint devuelto = monto - fee;

        // Limpiar primero (prevención de reentradas)
        devoluciones[msg.sender] = 0;

        // Guardar fee acumulado para el subastador
        acumuladoPorSubastador += fee;

        // Transferir saldo neto al postor
        payable(msg.sender).transfer(devuelto);

        emit RetiroConFee(msg.sender, devuelto, fee);
    }

    function finalizarSubasta() external {
        require(block.timestamp >= fin, "La subasta aun no ha terminado");
        require(!finalizada, "La subasta ya fue finalizada");

        finalizada = true;

        // Transferir oferta ganadora al subastador
        if (ofertaMaxima > 0) {
            payable(subastador).transfer(ofertaMaxima);
        }

        // Transferir fees acumulados
        if (acumuladoPorSubastador > 0) {
            payable(subastador).transfer(acumuladoPorSubastador);
            acumuladoPorSubastador = 0;
        }

        emit SubastaFinalizada(mejorPostor, ofertaMaxima, acumuladoPorSubastador);
    }
}
