const contractConfig = {
  airdrop: {
    tokenAmount: "10000000000000000000", // 10 MATIC in wei as a string
    maxParticipants: 1000,
    startDelay: 3600, // 1 hour from deployment
    duration: 1209600, // 14 days
  }
};

module.exports = contractConfig;
