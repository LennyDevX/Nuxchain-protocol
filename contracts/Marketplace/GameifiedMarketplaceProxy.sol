// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title GameifiedMarketplaceProxy
 * @dev UUPS Transparent Proxy para GameifiedMarketplaceV1
 * 
 * MEJORAS DE SEGURIDAD:
 * - Validación de que implementation es un contrato (no EOA)
 * - Validación de initializationData no vacío
 * - Eventos informativos para tracking on-chain
 * - Prevención de receive() accidental
 */
contract GameifiedMarketplaceProxy is ERC1967Proxy {
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // EVENTS
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    /// @notice Emitido cuando el proxy es inicializado correctamente
    event ProxyInitialized(address indexed implementation, uint256 initDataLength);
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // ERRORS
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    /// @notice Implementation no es un contrato válido
    error InvalidImplementation(address implementation);
    
    /// @notice initializationData está vacío
    error EmptyInitializationData();
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // CONSTRUCTOR
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    constructor(address implementation, bytes memory initializationData)
        ERC1967Proxy(implementation, initializationData)
    {
        // ✅ SECURITY: Validar que implementation es un contrato (no EOA)
        // Previene deployments accidentales con direcciones inválidas
        if (implementation.code.length == 0) {
            revert InvalidImplementation(implementation);
        }
        
        // ✅ SECURITY: Validar que initializationData no esté vacío
        // Asegura que la inicialización se ejecutará
        if (initializationData.length == 0) {
            revert EmptyInitializationData();
        }
        
        // ℹ️ EVENT: Emitir para tracking on-chain
        // Permite auditar todos los proxies desplegados
        emit ProxyInitialized(implementation, initializationData.length);
    }
    
    // ════════════════════════════════════════════════════════════════════════════════════════
    // FALLBACK PROTECTION
    // ════════════════════════════════════════════════════════════════════════════════════════
    
    /**
     * @dev Prevenir que ETH se quede atrapado en el proxy
     * @notice El proxy solo debe recibir llamadas delegadas al implementation
     */
    receive() external payable override {
        revert("GameifiedMarketplaceProxy: Cannot receive ETH directly");
    }
}