# 🚀 Smart Deployment System

Sistema inteligente de deployment para contratos de Nuxchain.

## Quick Start

```bash
# Instalar dependencias (si no lo has hecho)
npm install

# Generar artefactos compartidos para frontend / nuxchain-app
npm run build:frontend

# Ejecutar deployment inteligente
npx hardhat run scripts/DeploySmartV2.cjs --network polygon
```

## Frontend Package

El repo ahora incluye una frontera compartida en `export/` para exponer ABIs, direcciones y helpers reutilizables.

Comandos principales:

```bash
# Exportar solo ABIs
npm run export:abis

# Generar config y runtime del paquete export
npm run export:package

# Recomendado: regenerar todo el paquete compartido
npm run build:export
```

Outputs principales:

- `export/abis/runtime.js`
- `export/config/contracts.generated.json`
- `export/config/contracts.generated.ts`
- `export/config/contracts.generated.js`

Usa estos artefactos como base para `nuxchain-app` en vez de copiar archivos sueltos de deploy o ABIs manuales.

## Modos Disponibles

### 🎯 Smart Deploy (Recomendado)
Detecta automáticamente contratos modificados y sugiere la mejor estrategia.

**Cuándo usar**: Deployments regulares después de modificar contratos

### 🔄 Upgrade Only
Actualiza contratos existentes preservando todas las direcciones.

**Cuándo usar**: Bug fixes que no deben cambiar addresses

### 🆕 Deploy New
Deployment completo desde cero con nuevas direcciones.

**Cuándo usar**: Primera vez en una red o reset completo

### ✅ Custom Selection
Control manual completo de qué deployar y cómo.

**Cuándo usar**: Casos específicos con requirements particulares

## Estructura

```
scripts/
├── DeploySmartV2.cjs          # 🎯 Script principal - EJECUTAR ESTE
├── DeployAllContracts.cjs     # ⚠️  Legacy (sistema antiguo)
└── utils/
    ├── ContractAnalyzer.cjs   # Detecta cambios en contratos
    ├── AddressManager.cjs      # Gestiona direcciones
    ├── InteractiveMenu.cjs     # Menús interactivos
    └── DeploymentStrategy.cjs  # Ejecuta deployments
```

## Características

✅ Detección automática de contratos modificados  
✅ Preservación de direcciones mediante upgrades  
✅ Backups automáticos antes de deployar  
✅ Interfaz CLI interactiva  
✅ Verificación en Polygonscan  
✅ Dry-run mode para testing  
✅ Actualización automática de .env  

## Documentación Completa

Ver [SMART_DEPLOYMENT_GUIDE.md](../doc/SMART_DEPLOYMENT_GUIDE.md) para:
- Guía detallada de uso
- Arquitectura del sistema
- Troubleshooting
- Mejores prácticas
- FAQ

## Ejemplo de Uso

```bash
# 1. Compilar contratos
npx hardhat compile

# 2. Ejecutar deployment inteligente
npx hardhat run scripts/DeploySmartV2.cjs --network polygon

# Flujo interactivo:
# → Selecciona modo: Smart Deploy
# → Sistema detecta: "2 contratos modificados"
# → Sugiere: UPGRADE para staking, REDEPLOY para marketplace
# → Seleccionas contratos con checkboxes
# → Configuras opciones (backup, verify, etc.)
# → Confirmas deployment
# → Sistema ejecuta y muestra progreso
# → Resultado final con direcciones
```

## Comparación con Sistema Antiguo

| Feature | DeployAllContracts.cjs | DeploySmartV2.cjs |
|---------|----------------------|------------------|
| Detecta cambios | ❌ No | ✅ Sí (git + filesystem) |
| Preserva addresses | ❌ Siempre nuevas | ✅ UPGRADE preserva |
| Selección de contratos | ❌ Todos o nada | ✅ Interactive checkboxes |
| Backups | ❌ Manual | ✅ Automático |
| Interfaz | ⚠️ Ninguna | ✅ CLI interactivo |
| Dry-run | ❌ No | ✅ Sí |
| Estrategias | ❌ Una sola | ✅ 4 modos + custom |

## Notas Importantes

⚠️ **Staking**: Siempre usa UPGRADE para preservar addresses (frontend no cambia)  
⚠️ **Marketplace**: Puede tener nuevas addresses (actualizas frontend)  
⚠️ **Backups**: Siempre habilitado en mainnet  
⚠️ **Balance**: Asegúrate de tener suficiente MATIC (~1-2 MATIC)  

---

**Para soporte**: Ver documentación completa en `/doc/SMART_DEPLOYMENT_GUIDE.md`
