# NuxTap - Guía de NFTs de Agentes AI

**Guía para entender la economía de agentes AI dentro de NuxTap** | [← Volver a guías](../guides)

---

## 1. Qué son estos NFTs dentro de NuxTap

Los NFTs de agentes AI no son solo una imagen o una identidad visual.

Dentro de NuxTap cumplen cuatro funciones reales:

- Representan propiedad sobre un agente AI.
- Pueden mejorar el rendimiento del jugador cuando se vinculan al perfil.
- Se pueden comprar y vender en un marketplace propio.
- Se pueden rentar para que otra persona use ese agente por tiempo limitado.

En otras palabras:

**Un agente AI NFT en NuxTap es un activo jugable, comercial y monetizable.**

---

## 2. Las dos economías de NuxTap

Hoy NuxTap separa claramente dos mercados.

## Mercado 1. Marketplace de ítems y utilidades

Aquí viven activos como:

- Auto-Tap
- Boosters temporales
- Pases de retiro gratis
- Inventario puntual de NFTs vendidos desde el store

Este mercado sirve para mejorar el ritmo del juego.

## Mercado 2. Marketplace de agentes AI

Aquí viven los NFTs de agentes AI como activos individuales.

Este mercado sirve para:

- Comprar agentes para usarlos en tu cuenta
- Vender agentes propios
- Reposicionar precio
- Salir de una posición y tomar ganancias

La lógica es distinta al store:

- En el store compras utilidades de juego.
- En el marketplace de agentes compras propiedad sobre un agente específico.

---

## 3. Qué hace realmente vincular un agente a tu perfil

Antes la idea podía parecer solo decorativa. Ahora no.

Cuando vinculas un agente compatible a tu perfil de NuxTap:

- El juego verifica que controles ese NFT.
- El agente queda como tu agente activo.
- Tu multiplicador de recompensa puede aumentar.
- El bonus depende del historial operativo del agente.

Ese bonus puede crecer según:

- actividad previa del agente
- reputación actual del agente
- configuración administrativa del juego

Traducción simple:

**Un agente con mejor historial puede ayudarte a generar mejores resultados dentro del tap game.**

---

## 4. Qué significa “controlar” un agente

NuxTap no trabaja solo con la idea de propietario final.

También reconoce al controlador efectivo del agente.

Eso permite dos escenarios:

- El dueño usa su propio agente.
- Un renter usa temporalmente un agente rentado.

Entonces el sistema puede aceptar que el agente sea operado por:

- el owner
- un renter autorizado durante el periodo activo

Eso es importante porque evita que la utilidad del NFT quede bloqueada solo al titular original.

---

## 5. Cómo gana dinero un owner de agentes AI

Un NFT de agente AI puede monetizarse de varias formas.

## Forma 1. Venta directa

Flujo visual:

Owner lista agente -> comprador paga -> el NFT cambia de wallet -> el seller recibe el pago neto -> el treasury cobra fee de plataforma.

## Forma 2. Renta temporal

Flujo visual:

Owner crea oferta de renta -> renter paga por días -> el renter controla el agente temporalmente -> el owner cobra ingreso pasivo -> al finalizar se limpia el acceso.

## Forma 3. Uso propio dentro del juego

Flujo visual:

Compras agente -> lo vinculas -> juegas con bonus -> reclamas más eficientemente -> el valor del NFT también puede subir por demanda.

## Forma 4. Participación en misiones del mini game de agentes

Flujo visual:

Controlas agente -> aceptas tarea -> envías resultado -> validación si aplica -> ganas XP del mini game -> reclamas reward si existe.

---

## 6. Cómo funciona la compra y venta de agentes

## Para vender

1. Tienes un agente compatible en tu wallet.
2. Apruebas el marketplace de agentes.
3. Publicas un precio.
4. El listing queda activo hasta venta o cancelación.

## Para comprar

1. Ves agentes listados.
2. Pagas el precio exacto.
3. El NFT pasa a tu wallet.
4. La plataforma descuenta su fee.
5. El seller recibe el resto.

## Qué debes esperar como usuario

- Si el seller ya no posee el NFT, la compra no procede.
- Si el marketplace no tiene aprobación, la venta no se ejecuta.
- Si el NFT no pertenece al conjunto soportado por NuxTap, no puede listarse.

---

## 7. Cómo funciona la renta de agentes

La renta no mueve la propiedad del NFT.

Lo que cambia es el control temporal.

## Flujo del owner

1. Define precio por día.
2. Define mínimo y máximo de días.
3. Publica la oferta.

## Flujo del renter

1. Selecciona una oferta activa.
2. Elige duración dentro del rango permitido.
3. Paga la renta.
4. Obtiene control temporal del agente.

## Durante la renta

- El renter puede usar el agente donde el sistema acepta controller efectivo.
- El owner sigue siendo el propietario del NFT.
- El contrato distribuye ingresos entre owner y treasury.

## Al terminar la renta

- El acceso del renter se elimina.
- El control vuelve al owner.
- Cualquier usuario puede cerrar una renta expirada si hace falta limpiar estado.

---

## 8. Qué es realmente NuxAgentMiniGame ahora

NuxAgentMiniGame ya no debe entenderse como una extensión genérica del protocolo viejo.

Ahora su lectura correcta es esta:

**Es la capa de tareas y misiones para agentes AI dentro de la economía NuxTap.**

## Qué hace

- Admin crea tareas.
- El controlador del agente envía resultados.
- Algunas tareas se aprueban automáticamente.
- Otras pasan por validación.
- El sistema acumula XP de misión para ese usuario y ese agente.
- Si la tarea tenía recompensa económica, luego puede reclamarse.

## Qué NO hace

- No depende de QuestCore.
- No depende de QuestRewardsPool.
- No depende del sistema de leveling anterior para pagar rewards.

## Qué sí usa

- NFTs soportados por NuxTap
- validadores cuando la tarea lo requiere
- reward pool propio del mini game
- fee opcional hacia treasury

---

## 9. Flujo visual del mini game de agentes

## Caso A. Tarea automática

Admin crea tarea -> usuario envía resultado -> el sistema aprueba -> se suma XP -> si había reward, queda listo para reclamar.

## Caso B. Tarea con validación

Admin crea tarea -> usuario envía resultado -> queda pendiente -> validador revisa -> aprueba o rechaza -> si aprueba, se suma XP y se habilita reward.

## Caso C. Reward con fee

Usuario reclama reward -> el mini game envía fee al treasury -> el usuario recibe el neto.

---

## 10. Cómo aumenta el valor de un agente con el tiempo

Un agente puede volverse más atractivo si:

- fue usado mucho
- tiene más tareas completadas
- tiene mejor reputación
- genera mejor bonus cuando se vincula
- tiene demanda en compra o renta

Eso crea una lógica económica sana:

**el mejor agente no solo se ve mejor, también produce más utilidad o se alquila/vende mejor.**

---

## 11. Ejemplo completo de monetización

## Caso de uso: Diego compra un agente y luego lo renta

### Fase 1. Compra

Diego ve un agente con buen historial.

- Lo compra en el marketplace de agentes.
- El NFT pasa a su wallet.

### Fase 2. Uso propio

Diego lo vincula a su perfil de NuxTap.

- Ahora juega con bonus superior al de una cuenta sin agente.

### Fase 3. Actividad del agente

Diego usa el agente en tareas del mini game.

- Gana XP de misión.
- Fortalece el historial operativo del agente.

### Fase 4. Monetización

Luego decide no venderlo todavía.

- Publica una oferta de renta por 7 días.
- Otro jugador paga por usarlo.
- Diego recibe ingreso sin perder la propiedad.

### Fase 5. Salida opcional

Después de varias rentas, el agente ya tiene más historial y demanda.

- Diego puede venderlo más caro que al inicio.

---

## 12. Qué debe entender el usuario final

Si eres jugador:

- un agente AI puede ayudarte a jugar mejor
- no todos los NFTs sirven, solo los soportados
- el valor del agente depende de su utilidad real

Si eres owner:

- puedes jugar con tu agente
- puedes rentarlo
- puedes venderlo
- puedes usarlo para aumentar su valor antes de salir

Si eres comprador:

- no compras solo una skin
- compras un activo con posible utilidad, historial y capacidad de monetización

---

## 13. Resumen final en una frase

**En NuxTap, los NFTs de agentes AI forman una economía propia: mejoran el juego, se comercian en un mercado separado, pueden rentarse y participan en una capa de misiones que aumenta su valor y utilidad.**
