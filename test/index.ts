import { expect } from "chai";
import { ethers } from "hardhat";


describe("Deposit", function () {
  it("Should be able to deposit", async function () {

    const [deployer] = await ethers.getSigners();

    // deploy authority contract
    const FarmCoinAuthority = await ethers.getContractFactory("FarmCoinAuthority");
    const farmCoinAuthority = await FarmCoinAuthority.deploy(deployer.address, deployer.address, deployer.address, deployer.address);
    await farmCoinAuthority.deployed();
    console.log(`Deployed Authority contract:`, farmCoinAuthority.address);

    // deploy mock USDC
    const USDC = await ethers.getContractFactory("USDC");
    const usdc = await USDC.deploy(farmCoinAuthority.address);
    await usdc.deployed();
    console.log(`Deployed USDC:`, usdc.address);

    // deploy FarmCoin
    const FarmCoin = await ethers.getContractFactory("FarmCoin");
    const farmCoin = await FarmCoin.deploy(farmCoinAuthority.address);
    await farmCoin.deployed();
    console.log(`Deployed FarmCoin:`, farmCoin.address);

    // deploy Deposit contract
    const Deposit = await ethers.getContractFactory("DepositContract");
    const deposit = await Deposit.deploy(farmCoin.address, usdc.address, farmCoinAuthority.address);
    await deposit.deployed();
    console.log(`Deployed Deposit contract:`, deposit.address);


    // mint mock 1000 USDC
    await usdc.mint(deployer.address, "1000000000");

    // push vault to deposit contract
    await farmCoinAuthority.pushVault(deposit.address, true);

    await usdc.approve(deposit.address, "100000000")

    // deposit 100 USDC with no lock option
    await deposit.deposit("100000000", "0");

    // get remaining balance
    let usdcBalance = await usdc.balanceOf(deployer.address);

    expect(ethers.utils.formatUnits(usdcBalance, 'mwei')).to.equal("900.0"); // 900 USDC
    
    // withdraw deposit
    await deposit.withdraw("0");

    // get remaining balance
    usdcBalance = await usdc.balanceOf(deployer.address);

    expect(ethers.utils.formatUnits(usdcBalance, 'mwei')).to.equal("1000.0"); // 1000 USDC

    

    await usdc.approve(deposit.address, "100000000")

    // deposit 100 USDC with no lock option
    await deposit.deposit("100000000", "6");

    // get remaining balance
    usdcBalance = await usdc.balanceOf(deployer.address);

    expect(ethers.utils.formatUnits(usdcBalance, 'mwei')).to.equal("900.0"); // 900 USDC
    
    // withdraw deposit
    await deposit.withdraw("1");

    // get remaining balance
    usdcBalance = await usdc.balanceOf(deployer.address);

    expect(ethers.utils.formatUnits(usdcBalance, 'mwei')).to.equal("990.0"); // 1000 USDC
  });
});