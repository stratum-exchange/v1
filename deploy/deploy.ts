// zkSync deploy script
// npx hardhat deploy-zksync

import { Wallet, utils, Provider } from "zksync-web3";
import * as ethers from "ethers";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { Deployer } from "@matterlabs/hardhat-zksync-deploy";
import kekABI from "../abi/contracts/mock/LUSD.sol/LUSD.json";
import funABI from "../abi/contracts/mock/FUN.sol/FUN.json";
import zzzABI from "../abi/contracts/mock/ZZZ.sol/ZZZ.json";
import lpTokenABI from "../abi/contracts/multipool/LPToken.sol/LPToken.json";
import gaugeABI from "../abi/contracts/Gauge.sol/Gauge.json";

// import mainnet_config from "./constants/mainnet-config";
import testnet_config from "./testnet-config";

export default async function (hre: HardhatRuntimeEnvironment) {
  const CONFIG = testnet_config;
  let CONTRACTS = {
    Stratum: "",
    GaugeFactory: "",
    BribeFactory: "",
    PairFactory: "",
    Router: "",
    Library: "",
    VeArtProxy: "",
    VotingEscrow: "",
    RewardsDistributor: "",
    MetaBribe: "",
    Voter: "",
    WrappedExternalBribeFactory: "",
    Minter: "",
    StratumGovernor: "",
    MerkleClaim: "",
    WETH: "",
    KEK: "",
    FUN: "",
    ZZZ: "",
    Swap: "",
    swapToken: "",
  };

  console.log(`Running deploy script`);
  // console.log(CONFIG);

  const provider = new Provider("https://testnet.era.zksync.dev");
  // const provider = Provider.getDefaultProvider();
  // Initialize the wallet.
  const wallet = new Wallet(
    "24462fe894c87acf8d9b61a7ec234db8d67e1c4f38e0318885de53fa16b2299d",
    // "0x7726827caac94a7f9e1b160f7ea819f172f7b6f9d2a97f992c38edeab82d4110",
    provider
  );
  // if local: this is a RICH WALLET #1 PK: "0x7726827caac94a7f9e1b160f7ea819f172f7b6f9d2a97f992c38edeab82d4110"
  // https://github.com/matter-labs/local-setup/blob/main/rich-wallets.json

  // Create deployer object and load the artifact of the contract you want to deploy.
  const deployer = new Deployer(hre, wallet);

  // WETH (for local/testnet deployment)

  // const WETH = await deployer.loadArtifact("WETH");
  // // Estimate contract deployment fee
  // let deploymentFee = await deployer.estimateDeployFee(WETH, []);
  // let parsedFee = ethers.utils.formatEther(deploymentFee.toString());
  // console.log(`The deployment is estimated to cost ${parsedFee} ETH`);

  // const wethContract = await deployer.deploy(WETH, []);
  // // obtain the Constructor Arguments
  // console.log("constructor args:" + wethContract.interface.encodeDeploy([]));
  // // Show the contract info.
  // const wethAddress = wethContract.address;
  // console.log(`${WETH.contractName} was deployed to ${wethAddress}`);
  const wethAddress = "0x454B8576Eb63e9b36E087FDe38eB7Ab077A44263";
  CONTRACTS.WETH = wethAddress;

  // // STRATUM

  const Stratum = await deployer.loadArtifact("Stratum");
  // Estimate contract deployment fee
  let deploymentFee = await deployer.estimateDeployFee(Stratum, []);
  let parsedFee = ethers.utils.formatEther(deploymentFee.toString());
  console.log(`The deployment is estimated to cost ${parsedFee} ETH`);

  const stratumContract = await deployer.deploy(Stratum, []);
  //obtain the Constructor Arguments
  console.log("constructor args:" + stratumContract.interface.encodeDeploy([]));
  // Show the contract info.
  const stratumAddress = stratumContract.address;
  console.log(`${Stratum.contractName} was deployed to ${stratumAddress}`);
  CONTRACTS.Stratum = stratumAddress;

  // // // GAUGEFACTORY

  const GaugeFactory = await deployer.loadArtifact("GaugeFactory");
  // Estimate contract deployment fee
  deploymentFee = await deployer.estimateDeployFee(GaugeFactory, []);
  parsedFee = ethers.utils.formatEther(deploymentFee.toString());
  console.log(`The deployment is estimated to cost ${parsedFee} ETH`);

  const gaugeFactoryContract = await deployer.deploy(GaugeFactory, []);
  //obtain the Constructor Arguments
  console.log(
    "constructor args:" + gaugeFactoryContract.interface.encodeDeploy([])
  );
  // Show the contract info.
  const gaugeFactoryAddress = gaugeFactoryContract.address;
  console.log(
    `${GaugeFactory.contractName} was deployed to ${gaugeFactoryAddress}`
  );
  CONTRACTS.GaugeFactory = gaugeFactoryAddress;

  // // BRIBEFACTORY

  const BribeFactory = await deployer.loadArtifact("BribeFactory");
  // Estimate contract deployment fee
  deploymentFee = await deployer.estimateDeployFee(BribeFactory, []);
  parsedFee = ethers.utils.formatEther(deploymentFee.toString());
  console.log(`The deployment is estimated to cost ${parsedFee} ETH`);
  const bribeFactoryContract = await deployer.deploy(BribeFactory, []);
  //obtain the Constructor Arguments
  console.log(
    "constructor args:" + bribeFactoryContract.interface.encodeDeploy([])
  );
  // Show the contract info.
  const bribeFactoryAddress = bribeFactoryContract.address;
  console.log(
    `${BribeFactory.contractName} was deployed to ${bribeFactoryAddress}`
  );
  CONTRACTS.BribeFactory = bribeFactoryAddress;

  // // PAIRFACTORY

  const PairFactory = await deployer.loadArtifact("PairFactory");
  // Estimate contract deployment fee
  deploymentFee = await deployer.estimateDeployFee(PairFactory, []);
  parsedFee = ethers.utils.formatEther(deploymentFee.toString());
  console.log(`The deployment is estimated to cost ${parsedFee} ETH`);

  const pairFactoryContract = await deployer.deploy(PairFactory, []);
  //obtain the Constructor Arguments
  console.log(
    "constructor args:" + pairFactoryContract.interface.encodeDeploy([])
  );
  // Show the contract info.
  const pairFactoryAddress = pairFactoryContract.address;
  console.log(
    `${PairFactory.contractName} was deployed to ${pairFactoryAddress}`
  );
  CONTRACTS.PairFactory = pairFactoryAddress;

  // ROUTER

  const Router = await deployer.loadArtifact("Router");
  // Estimate contract deployment fee
  deploymentFee = await deployer.estimateDeployFee(Router, [
    // "0xB146B20e20cFe83CE7a9d79D4B22e1716A7E2213",
    // "0x9Ff4c7174c9b32D4E1bDf16201eE8a73Bf86DA7D",
    pairFactoryAddress,
    wethAddress,
  ]);
  parsedFee = ethers.utils.formatEther(deploymentFee.toString());
  console.log(`The deployment is estimated to cost ${parsedFee} ETH`);

  const routerContract = await deployer.deploy(Router, [
    // "0xB146B20e20cFe83CE7a9d79D4B22e1716A7E2213",
    // "0x9Ff4c7174c9b32D4E1bDf16201eE8a73Bf86DA7D",
    pairFactoryAddress,
    wethAddress,
  ]);
  //obtain the Constructor Arguments
  console.log(
    "constructor args:" +
      routerContract.interface.encodeDeploy([
        // "0xB146B20e20cFe83CE7a9d79D4B22e1716A7E2213",
        // "0x9Ff4c7174c9b32D4E1bDf16201eE8a73Bf86DA7D",
        pairFactoryAddress,
        wethAddress,
      ])
  );
  // Show the contract info.
  const routerAddress = routerContract.address;
  console.log(`${Router.contractName} was deployed to ${routerAddress}`);
  CONTRACTS.Router = routerAddress;

  // LUSD

  //LOGIC
  // let tx;
  // tx = await stratumContract.approve(routerAddress, BigInt(1000e18));
  // tx.wait();

  // tx = await routerContract.addLiquidityETH(
  //   stratumAddress,
  //   true,
  //   BigInt(1e18),
  //   "0",
  //   "0",
  //   "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
  //   100000000000,
  //   {
  //     // from: "0x77c82117Aa94C9e2DEFD6d679730be5826327558",
  //     from: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
  //     value: BigInt(1e18),
  //     // gasLimit: 60000,
  //   }
  // );
  // tx.wait(1);
  // console.log(tx);

  // STRATUMLIBRARY

  const StratumLibrary = await deployer.loadArtifact("StratumLibrary");
  // Estimate contract deployment fee
  deploymentFee = await deployer.estimateDeployFee(StratumLibrary, [
    routerAddress,
  ]);
  parsedFee = ethers.utils.formatEther(deploymentFee.toString());
  console.log(`The deployment is estimated to cost ${parsedFee} ETH`);

  const stratumLibraryContract = await deployer.deploy(StratumLibrary, [
    routerAddress,
  ]);
  //obtain the Constructor Arguments
  console.log(
    "constructor args:" +
      stratumLibraryContract.interface.encodeDeploy([routerAddress])
  );
  // Show the contract info.
  const stratumLibraryAddress = stratumLibraryContract.address;
  console.log(
    `${StratumLibrary.contractName} was deployed to ${stratumLibraryAddress}`
  );
  CONTRACTS.Library = stratumLibraryAddress;

  // VEARTPROXY

  const VeArtProxy = await deployer.loadArtifact("VeArtProxy");
  // Estimate contract deployment fee
  deploymentFee = await deployer.estimateDeployFee(VeArtProxy, []);
  parsedFee = ethers.utils.formatEther(deploymentFee.toString());
  console.log(`The deployment is estimated to cost ${parsedFee} ETH`);

  const veArtProxyContract = await deployer.deploy(VeArtProxy, []);
  //obtain the Constructor Arguments
  console.log(
    "constructor args:" + veArtProxyContract.interface.encodeDeploy([])
  );
  // Show the contract info.
  const veArtProxyAddress = veArtProxyContract.address;
  console.log(
    `${VeArtProxy.contractName} was deployed to ${veArtProxyAddress}`
  );
  CONTRACTS.VeArtProxy = veArtProxyAddress;

  // // VOTINGESCROW

  const VotingEscrow = await deployer.loadArtifact("VotingEscrow");
  // Estimate contract deployment fee
  deploymentFee = await deployer.estimateDeployFee(VotingEscrow, [
    stratumAddress,
    veArtProxyAddress,
  ]);
  parsedFee = ethers.utils.formatEther(deploymentFee.toString());
  console.log(`The deployment is estimated to cost ${parsedFee} ETH`);

  const votingEscrowContract = await deployer.deploy(VotingEscrow, [
    stratumAddress,
    veArtProxyAddress,
  ]);
  //obtain the Constructor Arguments
  console.log(
    "constructor args:" +
      votingEscrowContract.interface.encodeDeploy([
        stratumAddress,
        veArtProxyAddress,
      ])
  );
  // Show the contract info.
  const votingEscrowAddress = votingEscrowContract.address;
  console.log(
    `${VotingEscrow.contractName} was deployed to ${votingEscrowAddress}`
  );
  CONTRACTS.VotingEscrow = votingEscrowAddress;

  // // REWARDSDISTRIBUTOR

  const RewardsDistributor = await deployer.loadArtifact("RewardsDistributor");
  // Estimate contract deployment fee
  deploymentFee = await deployer.estimateDeployFee(RewardsDistributor, [
    votingEscrowAddress,
  ]);
  parsedFee = ethers.utils.formatEther(deploymentFee.toString());
  console.log(`The deployment is estimated to cost ${parsedFee} ETH`);

  const rewardsDistributorContract = await deployer.deploy(RewardsDistributor, [
    votingEscrowAddress,
  ]);
  //obtain the Constructor Arguments
  console.log(
    "constructor args:" +
      rewardsDistributorContract.interface.encodeDeploy([votingEscrowAddress])
  );
  // Show the contract info.
  const rewardsDistributorAddress = rewardsDistributorContract.address;
  console.log(
    `${RewardsDistributor.contractName} was deployed to ${rewardsDistributorAddress}`
  );
  CONTRACTS.RewardsDistributor = rewardsDistributorAddress;

  // // VOTER

  const Voter = await deployer.loadArtifact("Voter");
  // Estimate contract deployment fee
  deploymentFee = await deployer.estimateDeployFee(Voter, [
    votingEscrowAddress,
    pairFactoryAddress,
    gaugeFactoryAddress,
    bribeFactoryAddress,
  ]);
  parsedFee = ethers.utils.formatEther(deploymentFee.toString());
  console.log(`The deployment is estimated to cost ${parsedFee} ETH`);

  const voterContract = await deployer.deploy(Voter, [
    votingEscrowAddress,
    pairFactoryAddress,
    gaugeFactoryAddress,
    bribeFactoryAddress,
  ]);
  //obtain the Constructor Arguments
  console.log(
    "constructor args:" +
      voterContract.interface.encodeDeploy([
        votingEscrowAddress,
        pairFactoryAddress,
        gaugeFactoryAddress,
        bribeFactoryAddress,
      ])
  );
  // Show the contract info.
  const voterAddress = voterContract.address;
  console.log(`${Voter.contractName} was deployed to ${voterAddress}`);
  CONTRACTS.Voter = voterAddress;

  // // WRAPPEDEXTERNALBRIBEFACTORY

  const WrappedExternalBribeFactory = await deployer.loadArtifact(
    "WrappedExternalBribeFactory"
  );
  // Estimate contract deployment fee
  deploymentFee = await deployer.estimateDeployFee(
    WrappedExternalBribeFactory,
    [voterAddress]
  );
  parsedFee = ethers.utils.formatEther(deploymentFee.toString());
  console.log(`The deployment is estimated to cost ${parsedFee} ETH`);

  const wrappedExternalBribeFactoryContract = await deployer.deploy(
    WrappedExternalBribeFactory,
    [voterAddress]
  );
  //obtain the Constructor Arguments
  console.log(
    "constructor args:" +
      wrappedExternalBribeFactoryContract.interface.encodeDeploy([voterAddress])
  );
  // Show the contract info.
  const wrappedExternalBribeFactoryAddress =
    wrappedExternalBribeFactoryContract.address;
  console.log(
    `${WrappedExternalBribeFactory.contractName} was deployed to ${wrappedExternalBribeFactoryAddress}`
  );
  CONTRACTS.WrappedExternalBribeFactory = wrappedExternalBribeFactoryAddress;

  // // METABRIBE

  const MetaBribe = await deployer.loadArtifact("MetaBribe");
  // Estimate contract deployment fee
  deploymentFee = await deployer.estimateDeployFee(MetaBribe, [
    votingEscrowAddress,
    voterAddress,
    wrappedExternalBribeFactoryAddress,
    routerAddress,
    "0x0faF6df7054946141266420b43783387A78d82A9",
  ]);
  parsedFee = ethers.utils.formatEther(deploymentFee.toString());
  console.log(`The deployment is estimated to cost ${parsedFee} ETH`);

  const MetaBribeContract = await deployer.deploy(MetaBribe, [
    votingEscrowAddress,
    voterAddress,
    wrappedExternalBribeFactoryAddress,
    routerAddress,
    "0x0faF6df7054946141266420b43783387A78d82A9",
  ]);
  //obtain the Constructor Arguments
  console.log(
    "constructor args:" +
      MetaBribeContract.interface.encodeDeploy([
        votingEscrowAddress,
        voterAddress,
        wrappedExternalBribeFactoryAddress,
        routerAddress,
        "0x0faF6df7054946141266420b43783387A78d82A9",
      ])
  );
  // Show the contract info.
  const MetaBribeAddress = MetaBribeContract.address;
  console.log(`${MetaBribe.contractName} was deployed to ${MetaBribeAddress}`);
  CONTRACTS.MetaBribe = MetaBribeAddress;

  // // MINTER

  const Minter = await deployer.loadArtifact("Minter");
  // Estimate contract deployment fee
  deploymentFee = await deployer.estimateDeployFee(Minter, [
    voterAddress,
    votingEscrowAddress,
    rewardsDistributorAddress,
    MetaBribeAddress,
  ]);
  parsedFee = ethers.utils.formatEther(deploymentFee.toString());
  console.log(`The deployment is estimated to cost ${parsedFee} ETH`);

  const minterContract = await deployer.deploy(Minter, [
    voterAddress,
    votingEscrowAddress,
    rewardsDistributorAddress,
    MetaBribeAddress,
  ]);
  //obtain the Constructor Arguments
  console.log(
    "constructor args:" +
      minterContract.interface.encodeDeploy([
        voterAddress,
        votingEscrowAddress,
        rewardsDistributorAddress,
        MetaBribeAddress,
      ])
  );
  // Show the contract info.
  const minterAddress = minterContract.address;
  console.log(`${Minter.contractName} was deployed to ${minterAddress}`);
  CONTRACTS.Minter = minterAddress;

  // // STRATUMGOVERNOR

  const StratumGovernor = await deployer.loadArtifact("StratumGovernor");
  // Estimate contract deployment fee
  deploymentFee = await deployer.estimateDeployFee(StratumGovernor, [
    votingEscrowAddress,
  ]);
  parsedFee = ethers.utils.formatEther(deploymentFee.toString());
  console.log(`The deployment is estimated to cost ${parsedFee} ETH`);

  const stratumGovernorContract = await deployer.deploy(StratumGovernor, [
    votingEscrowAddress,
  ]);
  //obtain the Constructor Arguments
  console.log(
    "constructor args:" +
      stratumGovernorContract.interface.encodeDeploy([votingEscrowAddress])
  );
  // Show the contract info.
  const stratumGovernorAddress = stratumGovernorContract.address;
  console.log(
    `${StratumGovernor.contractName} was deployed to ${stratumGovernorAddress}`
  );
  CONTRACTS.StratumGovernor = stratumGovernorAddress;

  // // MERKLECLAIM (airdrop)

  const MerkleClaim = await deployer.loadArtifact("MerkleClaim");
  // Estimate contract deployment fee
  deploymentFee = await deployer.estimateDeployFee(MerkleClaim, [
    stratumAddress,
    CONFIG.merkleRoot,
  ]);
  parsedFee = ethers.utils.formatEther(deploymentFee.toString());
  console.log(`The deployment is estimated to cost ${parsedFee} ETH`);

  const merkleClaimContract = await deployer.deploy(MerkleClaim, [
    stratumAddress,
    CONFIG.merkleRoot,
  ]);
  //obtain the Constructor Arguments
  console.log(
    "constructor args:" +
      merkleClaimContract.interface.encodeDeploy([
        stratumAddress,
        CONFIG.merkleRoot,
      ])
  );
  // Show the contract info.
  const merkleClaimAddress = merkleClaimContract.address;
  console.log(
    `${MerkleClaim.contractName} was deployed to ${merkleClaimAddress}`
  );
  CONTRACTS.MerkleClaim = merkleClaimAddress;

  // // MULTIPOOL

  const KEKAddress = "0xE2Be1686641Dc8514e642f4EE5a2c282f4a56a94";
  const KEK = new ethers.Contract(KEKAddress, kekABI, provider);
  const FUNAddress = "0xc90B0DdCE3215e5dA55289c762727987446beA9A";
  const FUN = new ethers.Contract(FUNAddress, funABI, provider);
  const ZZZAddress = "0x0bdd248745F9D19BE665Fd157C58aDBEdf267677";
  const ZZZ = new ethers.Contract(ZZZAddress, zzzABI, provider);
  // const kek = await deployer.loadArtifact("LUSD");
  // const KEK = await deployer.deploy(kek);
  // const KEKAddress = KEK.address;
  // const fun = await deployer.loadArtifact("FUN");
  // const FUN = await deployer.deploy(fun);
  // const FUNAddress = FUN.address;
  // const zzz = await deployer.loadArtifact("ZZZ");
  // const ZZZ = await deployer.deploy(zzz);
  // const ZZZAddress = ZZZ.address;
  CONTRACTS.KEK = KEKAddress;
  CONTRACTS.FUN = FUNAddress;
  CONTRACTS.ZZZ = ZZZAddress;

  const Multipool = await deployer.loadArtifact("Swap");
  // Estimate contract deployment fee
  deploymentFee = await deployer.estimateDeployFee(Multipool, [
    [KEKAddress, FUNAddress, ZZZAddress],
    [18, 18, 18],
    "usd-3",
    "U3",
    20000,
    1000,
    500,
  ]);
  parsedFee = ethers.utils.formatEther(deploymentFee.toString());
  console.log(`The deployment is estimated to cost ${parsedFee} ETH`);

  const multiPoolContract = await deployer.deploy(Multipool, [
    [KEKAddress, FUNAddress, ZZZAddress],
    [18, 18, 18],
    "usd-3",
    "U3",
    20000,
    1000,
    500,
  ]);
  //obtain the Constructor Arguments
  console.log(
    "constructor args:" +
      multiPoolContract.interface.encodeDeploy([
        [KEKAddress, FUNAddress, ZZZAddress],
        [18, 18, 18],
        "usd-3",
        "U3",
        500,
        1e8,
        10 ** 10,
      ])
  );
  // Show the contract info.
  const multiPoolAddress = multiPoolContract.address;
  console.log(`${Multipool.contractName} was deployed to ${multiPoolAddress}`);
  CONTRACTS.Swap = multiPoolAddress;

  const swapStorage = await multiPoolContract.swapStorage();
  const swapTokenAddress = swapStorage.lpToken;
  // console.log("swaptoken", swapToken);
  const SwapToken = new ethers.Contract(swapTokenAddress, lpTokenABI, provider);
  CONTRACTS.swapToken = swapTokenAddress;

  // INITIALIZATION

  let tx = await stratumContract.initialMint(CONFIG.teamTreasure);
  tx.wait();

  tx = await stratumContract.setMerkleClaim(merkleClaimAddress);
  tx.wait();

  tx = await stratumContract.setMinter(minterAddress);
  tx.wait();

  tx = await pairFactoryContract.setPauser(CONFIG.teamEOA);
  tx.wait();

  tx = await votingEscrowContract.setVoter(voterAddress);
  tx.wait();

  tx = await votingEscrowContract.setTeam(CONFIG.teamEOA);
  tx.wait();

  tx = await voterContract.setGovernor(CONFIG.teamEOA);
  tx.wait();

  tx = await voterContract.setEmergencyCouncil(CONFIG.teamEOA);
  tx.wait();

  tx = await rewardsDistributorContract.setDepositor(minterAddress);
  tx.wait();

  tx = await stratumGovernorContract.setTeam(CONFIG.teamEOA);
  tx.wait();

  // check this
  tx = await multiPoolContract.setRebaseHandler(wallet.address);
  await tx.wait();

  tx = await MetaBribeContract.setDepositor(minterAddress);
  await tx.wait();

  tx = await MetaBribeContract.setGovernor(wallet.address);
  await tx.wait();

  // WHITELIST

  const nativeToken = [stratumAddress];
  const tokenWhitelist = nativeToken.concat(CONFIG.tokenWhitelist);
  tx = await voterContract.initialize(tokenWhitelist, minterAddress);
  tx.wait();

  console.log("set2");

  let partnerMax = ethers.BigNumber.from("1");
  let partnerAmts: string[] = [];
  for (let i in CONFIG.partnerAmts) {
    partnerAmts[i] = ethers.utils
      .parseUnits(CONFIG.partnerAmts[i].toString(), "ether")
      .toString();
    partnerMax = partnerMax.add(ethers.BigNumber.from(partnerAmts[i]));
  }

  console.log("set3");

  tx = await minterContract.initialize(
    CONFIG.partnerAddrs,
    CONFIG.partnerAmts,
    partnerMax
  );
  tx.wait();

  console.log("set4");

  tx = await minterContract.setTeam(CONFIG.teamMultisig);
  tx.wait();

  console.log("set5");

  console.log(`#Network: ${"chainId"}`);
  for (let i in CONTRACTS) {
    console.log(` - ${i} = ${CONTRACTS[i]}`);
  }
  console.log(CONTRACTS);

  const MAX_UINT256 = ethers.constants.MaxUint256;

  console.log(wallet.address);

  console.log("logged");

  // tx = await voterContract
  //   .connect(wallet)
  //   .whitelist(KEKAddress, { gasLimit: 3e7 });
  // await tx.wait();
  // tx = await voterContract
  //   .connect(wallet)
  //   .whitelist(FUNAddress, { gasLimit: 3e7 });
  // await tx.wait();
  // tx = await voterContract
  //   .connect(wallet)
  //   .whitelist(ZZZAddress, { gasLimit: 3e7 });
  // await tx.wait();

  // USDC
  tx = await voterContract
    .connect(wallet)
    .whitelist("0x20e2383fa3Ec3b2F4022D88CFD317907F721ffd5", { gasLimit: 3e7 });
  await tx.wait();
  console.log(
    await voterContract.isWhitelisted(
      "0x20e2383fa3Ec3b2F4022D88CFD317907F721ffd5"
    )
  );

  console.log("whitelisted");

  tx = await voterContract
    .connect(wallet)
    .createGauge3pool(
      SwapToken.address,
      KEKAddress,
      FUNAddress,
      ZZZAddress,
      wrappedExternalBribeFactoryAddress,
      { gasLimit: 3e7 }
    );
  await tx.wait();

  console.log("created gauge");

  const gauge_address = await voterContract.gauges(SwapToken.address);
  tx = await multiPoolContract.setRebaseHandler(gauge_address);
  await tx.wait();

  console.log("set");

  tx = await KEK.connect(wallet).approve(multiPoolAddress, MAX_UINT256);
  await tx.wait();
  tx = await FUN.connect(wallet).approve(multiPoolAddress, MAX_UINT256);
  await tx.wait();
  tx = await ZZZ.connect(wallet).approve(multiPoolAddress, MAX_UINT256);
  await tx.wait();

  console.log("approved");

  // console.log((await KEK.balanceOf(wallet.address)) / 1e18);
  // console.log((await KEK.allowance(wallet.address, multiPoolAddress)) / 1e18);
  // console.log((await FUN.balanceOf(wallet.address)) / 1e18);
  // console.log((await FUN.allowance(wallet.address, multiPoolAddress)) / 1e18);
  // console.log((await ZZZ.balanceOf(wallet.address)) / 1e18);
  // console.log((await ZZZ.allowance(wallet.address, multiPoolAddress)) / 1e18);

  // remember to check libraries
  let txx = await multiPoolContract
    .connect(wallet)
    .addLiquidity(
      [BigInt(10e18), BigInt(10e18), BigInt(10e18)],
      0,
      MAX_UINT256,
      {
        gasLimit: 3e7,
      }
    );
  await txx.wait();

  console.log("added liq");

  tx = await stratumContract
    .connect(wallet)
    .approve(votingEscrowAddress, MAX_UINT256);
  await tx.wait();

  console.log(await stratumContract.balanceOf(wallet.address));

  tx = await votingEscrowContract
    .connect(wallet)
    .create_lock_for(BigInt(1000e18), 365 * 86400, wallet.address, {
      gasLimit: 3e7,
    });
  await tx.wait();

  console.log("lock created");

  tx = await SwapToken.connect(wallet).approve(gauge_address, MAX_UINT256);
  await tx.wait();

  console.log("approved");

  const gauge = new ethers.Contract(gauge_address, gaugeABI, provider);

  tx = await gauge.connect(wallet).deposit(BigInt(30e18), 1, { gasLimit: 3e7 });
  await tx.wait();

  console.log("deposited");

  tx = await pairFactoryContract.connect(wallet).create3Pool(multiPoolAddress);
  await tx.wait();

  tx = await minterContract.update_period();
  await tx.wait();

  tx = await stratumContract
    .connect(wallet)
    .approve(routerAddress, MAX_UINT256);
  tx.wait();

  tx = await routerContract
    .connect(wallet)
    .addLiquidityETH(
      stratumAddress,
      true,
      BigInt(10e18),
      "0",
      "0",
      "0x77c82117Aa94C9e2DEFD6d679730be5826327558",
      MAX_UINT256,
      {
        from: "0x77c82117Aa94C9e2DEFD6d679730be5826327558",
        // from: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
        value: BigInt(1e16),
        // gasLimit: 60000,
      }
    );
  tx.wait();
  console.log("liq added");

  const pool = await routerContract.pairFor(
    "0x454B8576Eb63e9b36E087FDe38eB7Ab077A44263",
    stratumAddress,
    true
  );

  tx = await voterContract
    .connect(wallet)
    .createGauge(pool, wrappedExternalBribeFactoryAddress, {
      gasLimit: 3e7,
    });
  await tx.wait();
}
