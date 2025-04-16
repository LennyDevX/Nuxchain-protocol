module.exports = {
    airdrop: {
        tokenAmount: 5, // 5 MATIC por usuario
        startDelay: Math.floor((new Date('2024-01-01T00:00:00Z').getTime() / 1000) - Date.now() / 1000), // 1 de Enero 2024
        duration: 30 * 24 * 60 * 60, // 30 días
        maxParticipants: 100, // Total entre ambas fases
        minBalance: "1",
        phases: {
            phase1: {
                maxParticipants: 50,
                tokenAmount: 5, // 5 MATIC por usuario
                duration: 15 * 24 * 60 * 60 // 15 días
            },
            phase2: {
                maxParticipants: 50,
                tokenAmount: 5, // 5 MATIC por usuario
                duration: 15 * 24 * 60 * 60 // 15 días
            }
        }
    }
};
