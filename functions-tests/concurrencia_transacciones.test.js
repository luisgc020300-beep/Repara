// functions-tests/concurrencia_transacciones.test.js
//
// Auditoría R7 (octubre 2026): archivarElemento (y, antes, registrarPago/
// responderCambioAlcance) asumen que tx.get(collectionRef) dentro de una
// transacción protege frente a que un documento NUEVO aparezca en esa misma
// colección mientras la transacción sigue abierta -- no solo frente a que
// un documento YA LEÍDO se modifique. Esto nunca se había comprobado de
// forma decisiva: los tests de concurrencia anteriores (test 9/14 de
// elementos.test.js, test 5 de cambios_alcance.test.js) usan Promise.all,
// cuya ordenación real depende de la latencia relativa de cada llamada --
// pueden "pasar" simplemente porque, en la práctica, una siempre termina su
// lectura antes de que la otra escriba, no porque Firestore lo garantice.
//
// Este test fuerza la secuencia exacta que esos tests dejaban al azar:
// escribe un documento nuevo en la colección DESPUÉS de que la transacción
// ya la haya leído, pero ANTES de que la transacción intente comprometerse
// -- y cuenta cuántas veces Firestore ejecuta de verdad el cuerpo de la
// transacción (una sola vez == no detectó el conflicto y confirmó con una
// lectura obsoleta; más de una vez == lo detectó y reintentó, viendo ya el
// documento nuevo en el reintento).
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { db, idUnico } = require('./helpers');

test(
  '1. una transacción que ya leyó una colección SÍ reintenta si aparece un documento nuevo en ella antes de comprometerse',
  async () => {
    const casaId = idUnico('casa');
    const elementoId = idUnico('elemento');
    const elRef = db.collection('casas').doc(casaId).collection('elementos').doc(elementoId);
    await elRef.set({ nombre: 'Elemento de prueba de concurrencia' });

    let intentos = 0;
    let tamanoVistoEnElIntentoQueComprometio = -1;

    await db.runTransaction(async (tx) => {
      intentos += 1;
      const esteIntento = intentos;
      const registrosSnap = await tx.get(elRef.collection('registros'));
      tamanoVistoEnElIntentoQueComprometio = registrosSnap.size;

      // Solo en el PRIMER intento: mientras esta transacción ya ha leído la
      // colección (0 documentos) pero todavía no ha comprometido nada,
      // otro escritor -- fuera de la transacción -- añade un registro
      // nuevo con trabajo profesional activo a esa misma colección.
      if (esteIntento === 1) {
        await elRef.collection('registros').add({
          titulo: 'Trabajo colado durante la transacción',
          esConProfesional: true,
          estado: 'nuevo',
        });
      }

      tx.update(elRef, { marcadorDePrueba: true });
    });

    const registrosFinal = await elRef.collection('registros').get();

    console.log(
      `[concurrencia] intentos del cuerpo de la transacción: ${intentos}; ` +
      `tamaño de la colección visto en el intento que comprometió: ${tamanoVistoEnElIntentoQueComprometio}; ` +
      `tamaño real final de la colección: ${registrosFinal.size}`,
    );

    // La aserción real de esta auditoría: si Firestore protege contra esta
    // carrera, el intento que de verdad comprometió DEBE haber visto ya el
    // documento colado (reintentó tras detectar el conflicto). Si esto
    // falla, confirma que tx.get(collectionRef) NO protege contra
    // documentos nuevos -- un hallazgo de seguridad real, no teórico.
    assert.ok(
      intentos > 1,
      `Firestore ejecutó el cuerpo de la transacción una sola vez (no reintentó) ` +
      `pese a que se añadió un documento nuevo a una colección ya leída -- ` +
      `tx.get(collectionRef) NO protege contra documentos nuevos en esta configuración.`,
    );
    assert.equal(
      tamanoVistoEnElIntentoQueComprometio,
      registrosFinal.size,
      'el intento que comprometió debió ver ya el documento colado, no una lectura obsoleta',
    );
  },
);
