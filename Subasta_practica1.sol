// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

contract SubastaBasica {
    // Variables de estado
    address public subastador;         // Dirección del que crea la subasta
    uint public ofertaBase;            // Monto mínimo aceptado
    uint public ofertaMaxima;          // Oferta más alta actual
    address public mejorPostor;        // Dirección del mejor postor
    bool public finalizada;            // Estado de la subasta

    uint public inicio;  // momento de inicio al deployar
    uint public fin;     // momento de finalizacion
    uint constant EXTENSION_TIEMPO = 10 minutes; // Tiempo extra si hay oferta en últimos 10 min
    uint constant INCREMENTO_MINIMO_PORCENTUAL = 5;
    uint constant FEE_PORCENTUAL = 2;

    uint public acumuladoPorSubastador; // Monto total acumulado de comisiones

    mapping(address => uint) public devoluciones; // Para permitir retiros a postores superados

    // Eventos
    event NuevaOferta(address indexed postor, uint cantidad, uint nuevoFin);
    event SubastaFinalizada(address ganador, uint cantidad, uint totalComisiones);
    event RetiroConFee(address indexed postor, uint devuelto, uint feeCobrado);


    constructor(uint _duracionSegundos) {
        subastador = msg.sender;                       // Guarda direccion del subastador al deployar
        ofertaBase = 2 ether;                          // Precio inicial de la subasta
        inicio = block.timestamp;                      // Comienza al desplegar
        fin = block.timestamp + 2 days;                // Finaliza luego del tiempo indicado
    }


    // Constructor: se ejecuta al desplegar el contrato
    constructor() {
        subastador = msg.sender;  // El creador del contrato es el subastador
    }

    // Función para hacer ofertas verificando actividad de subasta y valor anterior ofertado

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

        // Guardar para retiro la oferta anterior
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

    // Permitir a postores superados retirar su dinero
    function retirar() external {
        uint monto = devoluciones[msg.sender];
        require(monto > 0, "No hay nada para retirar");

        devoluciones[msg.sender] = 0;
        payable(msg.sender).transfer(monto);
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
