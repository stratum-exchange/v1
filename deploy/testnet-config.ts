// zkSync testnet config

const TEAM_MULTISIG = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266";
const TEAM_EOA = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266";
const WETH = "0x454B8576Eb63e9b36E087FDe38eB7Ab077A44263";
const LUSD = "0xF9Cf10B3742ac257eC669Ff5FB19bDD50A809326";
const testnetArgs = {
  WETH: WETH,
  LUSD: LUSD,
  teamEOA: TEAM_EOA,
  teamTreasure: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
  teamMultisig: TEAM_MULTISIG,
  emergencyCouncil: TEAM_EOA,
  merkleRoot:
    "0x6362f8fcdd558ac55b3570b67fdb1d1673bd01bd53302e42f01377f102ac80a9", // boilerplate
  tokenWhitelist: [
    "0xE2Be1686641Dc8514e642f4EE5a2c282f4a56a94",
    "0xc90B0DdCE3215e5dA55289c762727987446beA9A",
    "0x0bdd248745F9D19BE665Fd157C58aDBEdf267677",
    "0xbAF72402f98f16e77638Ce5FCC5689CD1627E8ff", // usdc on mantle testnet
  ],
  partnerAddrs: [],
  partnerAmts: [0],
};

export default testnetArgs;
