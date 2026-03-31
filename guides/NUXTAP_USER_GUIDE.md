# NuxTap - Guía de Usuario

**Guía práctica para jugadores y compradores del mini juego NuxTap** | [← Volver a guías](../guides)

---

## 1. Qué es NuxTap hoy

NuxTap es un mini juego standalone dentro del ecosistema, enfocado en una experiencia simple:

- Tocas para generar progreso.
- Subes score y nivel.
- Compras mejoras en un mini marketplace.
- Acumulas recompensas respaldadas por treasury.
- Puedes comprar y vincular NFTs de agente compatibles.

La versión actual ya incluye estas piezas funcionando:

- Juego de taps manuales.
- Auto-tap pasivo mediante ítems.
- Boosters temporales.
- Reclamo de recompensas con o sin comisión.
- Marketplace interno de ítems y utilidades.
- Marketplace separado para agentes AI.
- Venta directa de NFTs de agente desde inventario del store.
- Vinculación de un NFT compatible a tu perfil con utilidad real en rewards.
- Renta de agentes AI para uso temporal.

Importante:

- NuxTap no depende del sistema de quests para sus recompensas.
- NuxTap usa su propio treasury.
- NuxTap solo interactúa con NFTs compatibles y aprobados.

---

## 2. La idea en una sola vista

**Flujo simple del jugador:**

Conectas wallet -> entras al juego -> haces una sesión de taps -> ganas score y rewards -> compras mejoras -> vuelves a jugar con ventaja -> reclamas POL cuando quieras.

**Flujo extendido con marketplace y NFT:**

Conectas wallet -> compras Auto-Tap o Booster -> mejoras tu ritmo -> compras o vinculas un NFT de agente -> obtienes bonus si ese agente aporta valor -> sigues acumulando progreso -> reclamas rewards respaldadas por treasury.

## Dos marketplaces distintos

- El store de NuxTap concentra ítems y utilidades rápidas.
- El marketplace de agentes AI concentra compra y venta de agentes individuales.
- Esto separa consumo de corto plazo y activos estratégicos de largo plazo.

---

## 3. Ejemplo completo paso a paso

## Caso de uso: Ana entra por primera vez

### Paso 1. Ana conecta su wallet

Ana entra al frontend de NuxTap y conecta su wallet en Polygon.

En ese momento empieza con un perfil vacío:

- Score total: 0
- Nivel actual: 0
- Recompensas sin reclamar: 0
- Auto-tap: 0
- Booster activo: no
- NFT vinculado: ninguno

### Paso 2. Ana hace su primera sesión manual

Ana toca la pantalla y cierra una sesión con 100 taps manuales.

Qué ocurre internamente:

- El juego toma esos taps manuales.
- Revisa su límite diario disponible.
- Calcula score ganado.
- Calcula recompensa provisional.
- Reserva esa recompensa dentro del treasury.
- Actualiza su perfil.

Resultado visible para Ana:

- Ya tiene score.
- Ya tiene una primera recompensa acumulada.
- Su última actividad queda registrada.

### Paso 3. Ana entra al marketplace

En el marketplace ve cuatro tipos de activos:

- Auto-Tap NFT/ítem
- Booster temporal
- Pase de retiro gratis
- NFT de agente AI

Decide comprar:

- 1 Auto-Tap
- 1 Booster temporal
- 1 Pase de retiro gratis

### Paso 4. Ana activa sus mejoras

Ana usa el Auto-Tap.

Qué consigue:

- Su perfil gana una tasa de auto-tap permanente mientras conserve esa mejora aplicada.
- A partir de ahí puede generar taps pasivos entre sesiones.

Luego activa el Booster.

Qué consigue:

- Durante un tiempo limitado, sus sesiones usan un multiplicador mayor.
- Eso mejora score y reward de esa ventana activa.

### Paso 5. Ana deja pasar tiempo

Ana se va 15 minutos y vuelve.

Qué pasa en ese tiempo:

- El sistema calcula taps pasivos según su auto-tap rate.
- Esos taps no se pagan automáticamente en tiempo real.
- Se incorporan cuando Ana liquida una nueva sesión.

### Paso 6. Ana liquida una nueva sesión

Ana vuelve y hace 50 taps manuales.

En esta nueva liquidación se suman:

- Sus taps manuales actuales.
- Los taps pasivos acumulados.
- El multiplicador del booster si sigue activo.
- El multiplicador del nivel.
- El bono por streak si aplica.

Resultado típico para Ana:

- Más score que en la primera sesión.
- Más rewards acumuladas.
- Mejor progreso hacia el siguiente nivel.

### Paso 7. Ana reclama rewards

Ana decide retirar todo lo acumulado.

Tiene dos caminos:

**Opción A: reclamar normalmente**

- El sistema aplica la comisión de claim configurada.
- El neto llega a su wallet.

**Opción B: usar un Pase de retiro gratis**

- Consume ese ítem.
- La comisión se vuelve 0 en ese claim.
- Recibe el monto completo de ese retiro.

### Paso 8. Ana compra un NFT de agente

Más tarde ve un NFT de agente listado en el store.

Ese NFT no es una mejora fungible del tipo Auto-Tap.
Es un NFT individual del inventario del marketplace.

Cuando lo compra:

- El NFT sale del inventario del store.
- El NFT pasa a su wallet.
- Ya es propietaria real de ese activo.

### Paso 9. Ana vincula ese NFT a su perfil

Si el NFT está soportado por NuxTap y además está registrado como compatible, Ana puede vincularlo a su perfil de juego.

Qué significa hoy:

- Su perfil queda asociado a ese NFT.
- El frontend puede mostrar ese agente como su agente activo.
- El sistema guarda qué contrato y qué token tiene vinculados.
- El agente puede aportar un bonus real al multiplicador de rewards del juego.
- Ese bonus depende del historial operativo y reputación del agente cuando están disponibles.

En resumen:

- Vincular ya no es solo representación visual.
- Vincular puede mejorar el rendimiento del jugador.
- Un mejor agente puede traducirse en mejor eficiencia dentro del loop de taps.

---

## 4. Cómo se juega realmente

## Bucle principal del juego

### Etapa 1. Jugar

El jugador realiza taps manuales.

### Etapa 2. Liquidar

El juego convierte la sesión en:

- taps acreditados
- score
- rewards reservadas
- avance de nivel

### Etapa 3. Mejorar

El jugador compra y usa ítems del marketplace para jugar mejor.

### Etapa 4. Reclamar

El jugador decide cuándo convertir sus rewards acumuladas en POL enviado a su wallet.

### Etapa 5. Repetir

El jugador vuelve con mejor nivel, mejores ítems y posiblemente un NFT de agente vinculado.

---

## 5. Cómo funcionan las rewards

Las rewards no salen de la nada.

NuxTap usa un treasury dedicado que cumple dos funciones:

- Recibir fondos de recompensa prefundados.
- Recibir ingresos del marketplace.

Después, ese treasury paga las rewards del juego.

## Qué significa “respaldado por treasury”

Cuando el jugador liquida una sesión:

- El juego calcula cuánto debería ganar.
- Revisa la liquidez disponible en el treasury.
- Reserva ese monto si hay liquidez suficiente.
- Ese saldo queda reflejado como reward sin reclamar del jugador.

Esto reduce el riesgo de mostrar recompensas imposibles de pagar.

## Qué ve el jugador

El jugador percibe algo así:

- Juego ahora.
- Se me acredita reward.
- Puedo dejarla acumulada.
- La reclamo cuando quiera.

## Qué puede limitar el claim

Las rewards dependen de varios factores:

- Liquidez disponible del treasury.
- Límite máximo de payout individual.
- Límite diario de payout global.
- Comisión de claim si no usa pase.

---

## 6. Cómo funcionan los niveles

El nivel del jugador depende del score total acumulado.

Mientras más score tenga:

- mayor puede ser su límite diario
- mejor puede ser su multiplicador de reward

## Niveles por defecto hoy

| Nivel | Score requerido | Límite diario de taps | Multiplicador base |
|---|---:|---:|---:|
| 0 | 0 | 5,000 | 1.00x |
| 1 | 1,000 | 7,500 | 1.05x |
| 2 | 5,000 | 10,000 | 1.15x |
| 3 | 15,000 | 15,000 | 1.25x |

Importante:

- Estos valores son administrables.
- El dashboard admin puede cambiarlos más adelante.

---

## 7. Qué es el streak y por qué importa

El streak premia al jugador que vuelve en días consecutivos.

Si el jugador juega en días seguidos:

- mantiene su racha
- aumenta su bonus adicional

Si deja pasar demasiado tiempo:

- la racha vuelve a empezar

En la configuración actual, el bonus de streak añade un extra porcentual por continuidad.

En términos simples:

- Día 1: juegas normal
- Día 2 seguido: un poco mejor
- Día 3 seguido: mejor todavía

---

## 8. Marketplace: qué vende y cómo funciona

El marketplace actual de NuxTap es un **store directo del protocolo al usuario**.

No es todavía un mercado libre entre usuarios.

## Qué significa eso

Hoy el flujo es:

- El admin configura ítems.
- El admin deposita NFTs de agente cuando aplique.
- El jugador compra directamente al store.

No hay todavía:

- ofertas entre usuarios
- subastas de jugador a jugador
- reventa P2P dentro de NuxTap

## Categorías actuales del marketplace

| Categoría | Qué compra el usuario | Para qué sirve |
|---|---|---|
| Auto-Tap | Mejora utilitaria | Genera taps pasivos entre sesiones |
| Booster temporal | Mejora consumible | Mejora temporalmente la rentabilidad de la sesión |
| Pase de retiro gratis | Mejora consumible | Elimina la comisión del claim en un retiro |
| NFT de agente AI | NFT individual | Activo coleccionable/comprable y vinculable al perfil |

---

## 9. Detalle de cada ítem del marketplace

## 9.1 Auto-Tap

El Auto-Tap es una mejora de utilidad.

Qué hace:

- Aumenta tu tasa de taps pasivos.
- Hace que el juego siga generando taps mientras no estás tocando activamente.

Ejemplo simple:

- Compras 1 Auto-Tap.
- Tu tasa sube.
- Esperas un tiempo.
- En la próxima liquidación aparecen taps extra.

Valor por defecto actual:

- Precio de ejemplo: 0.01 POL
- Valor base: +1 de auto-tap rate

Lectura práctica para usuario:

- No te paga al instante.
- Mejora tu siguiente liquidación.

## 9.2 Booster temporal

El Booster mejora tu rendimiento por tiempo limitado.

Qué hace:

- Sube tu multiplicador de sesión durante la ventana activa.

Valor por defecto actual:

- Precio de ejemplo: 0.02 POL
- Duración de ejemplo: 1 hora
- Intensidad de ejemplo: +25%

Lectura práctica para usuario:

- Es ideal antes de una sesión fuerte.
- Conviene usarlo cuando vas a jugar y liquidar varias veces.

## 9.3 Pase de retiro gratis

Es un ítem pensado para proteger el valor del claim.

Qué hace:

- Cuando reclamas rewards y consumes este pase, la comisión del claim baja a 0.

Valor por defecto actual:

- Precio de ejemplo: 0.005 POL

Lectura práctica para usuario:

- Es útil si ya acumulaste una buena cantidad.
- Sirve para retirar limpio y conservar el total del claim.

## 9.4 NFT de agente AI

Es un NFT real, individual y único.

Qué hace:

- Lo compras como activo digital.
- Llega a tu wallet.
- Puedes vincularlo a tu perfil si es compatible.

Lectura práctica para usuario:

- No es un consumible.
- No se quema al usarlo.
- No es lo mismo que un Auto-Tap o un Booster.

---

## 10. Cómo funcionan los NFTs en NuxTap

NuxTap trabaja con dos lógicas de activos distintas.

## A. Ítems utilitarios del juego

Incluyen:

- Auto-Tap
- Booster
- Pase de retiro gratis

Características:

- Son ítems de utilidad.
- Pueden configurarse como soulbound.
- Si son soulbound, no se pueden transferir entre usuarios.
- Se consumen cuando el juego los usa.

## B. NFTs de agente

Características:

- Son NFTs individuales.
- Se venden uno por uno.
- Se transfieren al comprador al momento de la compra.
- Pueden usarse como activo vinculado al perfil si están soportados.

## Diferencia visual rápida

| Tipo | Se consume | Se puede vincular al perfil | Representa identidad única |
|---|---|---|---|
| Auto-Tap | Sí | No | No |
| Booster | Sí | No | No |
| Pase de retiro | Sí | No | No |
| NFT de agente | No | Sí | Sí |

---

## 11. Qué significa “soulbound”

Un ítem soulbound es un activo que queda pegado a tu cuenta y no se puede transferir normalmente a otra wallet.

En la configuración por defecto actual:

- Los ítems utilitarios del juego se venden como soulbound.

Eso significa:

- No compras un Booster para revenderlo.
- Lo compras para usarlo tú.
- El valor está en el efecto, no en la reventa.

---

## 12. Cómo funciona la compra de NFTs de agente

El flujo actual es este:

### Paso 1. El admin deposita NFTs en el store

El marketplace necesita inventario real.

Eso significa que primero el admin coloca NFTs de agente dentro del store.

### Paso 2. El usuario compra uno

Cuando el usuario paga:

- el store valida que sí hay inventario
- saca un NFT del inventario
- lo transfiere al comprador

### Paso 3. El inventario baja

Cada compra reduce la cantidad disponible de ese ítem NFT.

### Qué debe entender el usuario

- Si no hay inventario, no se puede comprar ese NFT.
- No todos los ítems funcionan así.
- Esto solo aplica a la categoría de NFT de agente.

---

## 13. Cómo funciona la vinculación de NFTs al perfil

Vincular un NFT no es lo mismo que comprarlo.

Para vincularlo, deben cumplirse estas condiciones:

- El contrato NFT debe estar soportado por NuxTap.
- El NFT debe estar registrado como compatible si hay registry activo.
- El jugador debe ser el owner real del token.

Cuando se vincula:

- el perfil guarda el contrato del NFT
- el perfil guarda el token ID

## Qué gana el jugador hoy

- Identidad visual y estructural dentro del juego.
- Base para futuras experiencias ligadas a agentes.
- Un perfil más rico para frontend y socialización.

## Qué no gana automáticamente hoy

- Un multiplicador extra por solo vincularlo.
- Claims adicionales por solo tenerlo vinculado.

---

## 14. Valores base actuales del juego

Estos son los valores que hoy describen la experiencia inicial desplegada por defecto.

| Parámetro | Valor base actual |
|---|---|
| Reward por tap | 0.00001 POL |
| Límite manual por sesión | 1,000 taps |
| Tick pasivo | cada 5 minutos |
| Comisión normal de claim | 5% |
| Bono de streak | +1.5% por continuidad adicional |

## Valores por defecto del marketplace actual

| Ítem | Precio de ejemplo | Efecto de ejemplo |
|---|---:|---|
| Auto-Tap | 0.01 POL | +1 auto-tap rate |
| Booster | 0.02 POL | +25% por 1 hora |
| Pase de retiro gratis | 0.005 POL | claim sin fee |
| NFT de agente | variable | NFT real del inventario |

Nota importante:

- El admin puede cambiar estos valores.
- Tómalos como configuración inicial, no como promesa fija eterna.

---

## 15. Límites y reglas que el usuario debe conocer

## Límite por sesión

No puedes liquidar más taps manuales que el máximo permitido por sesión.

## Límite diario

Aunque juegues mucho, solo se te acreditará hasta tu cap diario según tu nivel actual.

## Liquidez real

Tus rewards dependen de la liquidez del treasury.

## Claim con fee

Si no usas pase de retiro gratis, el claim aplica comisión.

## Claim sin fee

Si usas pase y el claim es válido, recibes el monto completo de ese retiro.

## Compatibilidad NFT

No cualquier NFT sirve para vincularse al perfil. Debe estar aprobado para NuxTap.

---

## 16. Ejemplos visuales rápidos

## Ejemplo A. Jugador casual

Mario entra 10 minutos al día:

1. Hace una sesión corta.
2. Acumula score.
3. Compra un Auto-Tap.
4. Al día siguiente vuelve con taps pasivos listos.
5. Repite y va subiendo de nivel.

Ideal para:

- usuarios que quieren progreso simple
- usuarios que no quieren estar conectados todo el tiempo

## Ejemplo B. Jugador optimizador

Laura quiere maximizar rendimiento:

1. Hace su sesión base.
2. Activa Booster.
3. Liquida varias veces dentro de la ventana activa.
4. Usa pase de retiro al momento de claim.
5. Reinvierta comprando más utilidades o un NFT de agente.

Ideal para:

- usuarios que miran números
- usuarios que sí planifican cuándo reclamar

## Ejemplo C. Coleccionista de agentes

Diego entra sobre todo por los NFTs:

1. Revisa el inventario del store.
2. Compra un NFT de agente.
3. Lo recibe en su wallet.
4. Lo vincula a su perfil.
5. Usa ese agente como identidad principal dentro del juego.

Ideal para:

- usuarios atraídos por identidad digital
- usuarios que quieren mezclar colección y juego

---

## 17. Qué ve el usuario en pantalla idealmente

Para que la experiencia sea clara, el frontend debería mostrar al menos estas áreas:

## Panel de jugador

- Nivel actual
- Score total
- Recompensas sin reclamar
- Recompensas ya reclamadas
- Racha actual
- Mejor racha
- Auto-tap rate
- Booster activo y tiempo restante

## Panel de sesión

- Taps manuales de la sesión
- Taps pasivos acumulados
- Total acreditado
- Reward estimada
- Cap diario restante

## Marketplace

- Nombre del ítem
- Precio
- Efecto
- Duración si aplica
- Stock si aplica
- Si es soulbound o no

## Perfil NFT

- NFT vinculado
- Token ID
- Colección
- Estado de compatibilidad

---

## 18. Preguntas frecuentes

## ¿Mis rewards se pagan automáticamente?

No. Primero se acumulan y luego tú las reclamas.

## ¿El auto-tap me paga aunque no juegue nunca más?

Genera taps pasivos, pero esos taps deben reflejarse en una liquidación de sesión para verse en tu progreso.

## ¿Puedo transferir mis ítems utilitarios?

Si fueron configurados como soulbound, no.

## ¿Puedo comprar varios NFTs de agente?

Sí, siempre que haya inventario y el store los tenga disponibles.

## ¿Puedo vincular cualquier NFT que compre?

No. Solo los contratos aprobados y compatibles con NuxTap.

## ¿Un NFT vinculado ya me da más rewards?

No automáticamente en la versión actual. Hoy la vinculación funciona como asociación de perfil y base de expansión futura.

## ¿Qué pasa si el treasury tiene poca liquidez?

El sistema limita las rewards al nivel de liquidez disponible, para evitar promesas de pago sin respaldo.

---

## 19. Qué existe hoy y qué viene después

## Lo que ya existe hoy

- Gameplay de taps manuales y pasivos.
- Score, niveles, caps y streaks.
- Claims respaldados por treasury.
- Marketplace directo con utilidades.
- Venta directa de NFTs de agente.
- Vinculación de NFT al perfil.

## Lo que razonablemente puede crecer después

- Utilidad avanzada de agentes vinculados.
- IA semiautónoma visible en frontend.
- Marketplace más profundo.
- Experiencias sociales alrededor del agente.
- Salón AI y automatizaciones futuras.

---

## 20. Resumen para el usuario

Si quieres entender NuxTap en una frase:

**Juegas, mejoras, acumulas y reclamas; y si quieres, conviertes tu perfil en una identidad NFT viva dentro del juego.**

Si quieres entenderlo en tres decisiones:

1. ¿Juegas casual o optimizado?
2. ¿Compras utilidades o también coleccionas agentes?
3. ¿Reclamas con fee o guardas un pase para reclamar completo?

---

**Última actualización**: 30 de marzo de 2026  
**Estado**: Basado en la implementación actual de NuxTap en el codebase  
**Enfoque**: Guía de usuario, no guía técnica