// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

contract SubastaBasica {
    // 📌 Variables de estado
    address public subastador;         // Dirección del que crea la subasta
	uint public ofertaBase;            // Monto mínimo aceptado
    uint public ofertaMaxima;          // Oferta más alta actual
    address public mejorPostor;        // Dirección del mejor postor
    bool public finalizada;            // Estado de la subasta

	uint public inicio;
    uint public fin;
    uint constant EXTENSION_TIEMPO = 10 minutes; // Tiempo extra si hay oferta en últimos 10 min

    mapping(address => uint) public devoluciones; // Para permitir retiros a postores superados

    // 🧾 Eventos
    event NuevaOferta(address indexed postor, uint cantidad);
    event SubastaFinalizada(address ganador, uint cantidad);

    constructor(uint _duracionSegundos) {
        subastador = msg.sender;
        inicio = block.timestamp;                      // Comienza al desplegar
        fin = block.timestamp + _duracionSegundos;     // Finaliza luego del tiempo indicado
    }

    // 🏗️ Constructor: se ejecuta al desplegar el contrato
    constructor() {
        subastador = msg.sender;  // El creador del contrato es el subastador
    }

    // 💸 Función para hacer ofertas
    function ofertar() external payable {
        require(!finalizada, "Subasta finalizada");
        require(msg.value > ofertaMaxima, "La oferta debe ser mayor a la actual");

        // Guardar para retiro la oferta anterior
        if (ofertaMaxima > 0) {
            devoluciones[mejorPostor] += ofertaMaxima;
        }

        mejorPostor = msg.sender;
        ofertaMaxima = msg.value;

        emit NuevaOferta(msg.sender, msg.value);
    }

    // 🔁 Permitir a postores superados retirar su dinero
    function retirar() external {
        uint monto = devoluciones[msg.sender];
        require(monto > 0, "No hay nada para retirar");

        devoluciones[msg.sender] = 0;
        payable(msg.sender).transfer(monto);
    }

    // ⛔ Finalizar la subasta y enviar los fondos al subastador
    function finalizarSubasta() external {
        require(msg.sender == subastador, "Solo el subastador puede finalizar");
        require(!finalizada, "La subasta ya se ha finalizado");

        finalizada = true;
        payable(subastador).transfer(ofertaMaxima);

        emit SubastaFinalizada(mejorPostor, ofertaMaxima);
    }
}
