const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Swapper Contract", function () {
  let owner;
  let user;
  let swapper;
  let feeData;
  let newExchangeAddress;
  let sellTokenAddress;
  let lockTxHash;

  before(async function () {
    this.timeout(1200000);

    // Get user and owner signers
    [owner, user] = await ethers.getSigners();
    console.log("Owner address:", owner.address);
    console.log("User address:", user.address);

    // sellTokenAddress
    sellTokenAddress = '0x779877a7b0d9e8603169ddbd7836e478b4624789';

    const swapperAddress = "0xd96C333c7f2E2280D166DC48482507d5510F8976";
    // const feeDataAddress = "0x2A25AE60482dF16222f3a0e58Ab8d5C15170843E";

    // Get the Swapper and FeeData contracts
    swapper = await ethers.getContractAt("Swapper", swapperAddress, owner);
    // feeData = await ethers.getContractAt("FeeData", feeDataAddress, owner);
  });

  // Function to convert uint to bytes32
  function uintToBytes32(uintValue) {
    const hexString = uintValue.toString(16).padStart(64, '0');
    return `0x${hexString}`;
  }

  async function performSwap(sellToken, buyToken, amount, userAddress) {
    const fetch = (await import('node-fetch')).default;

    const ERC20_ABI = [
      "function transfer(address to, uint256 amount) public returns (bool)",
      "function approve(address spender, uint256 amount) public returns (bool)",
      "function balanceOf(address account) external view returns (uint256)",
      "function allowance(address owner, address spender) external view returns (uint256)"
    ];

    // Get the ERC20 token contract
    const srcToken = new ethers.Contract(sellToken, ERC20_ABI, user);

    // Approve srcToken to swapper
    await srcToken.connect(owner).approve(swapper.target, amount);
    console.log("Approved tokens to swapper", amount.toString());

    const sellAmount = amount.toString();
    const apiKey = "03b24686-4712-4e62-a5ba-571b6ca9c61c";

    const response = await fetch(`https://sepolia.api.0x.org/swap/v1/quote?buyToken=${buyToken}&sellAmount=${sellAmount}&sellToken=${sellToken}&excludedSources=0x,Kyber`, {
      headers: {
        '0x-api-key': apiKey
      }
    });

    if (!response.ok) {
      throw new Error(`Failed to fetch quote: ${response.statusText}`);
    }

    const quoteData = await response.json();
    const { data } = quoteData;

    const abiCoder = new ethers.AbiCoder();
    const encodedData = abiCoder.encode(
      ["address", "address", "uint256", "bytes"],
      [sellToken, buyToken, amount, data]
    );

    return { encodedData, srcToken };
  }

  // Creating function for dummy call data 

  async function generatingDummydata(sellToken, buyToken, amount, userAddress, dummyAmount) {
    const fetch = (await import('node-fetch')).default;

    const ERC20_ABI = [
      "function transfer(address to, uint256 amount) public returns (bool)",
      "function approve(address spender, uint256 amount) public returns (bool)",
      "function balanceOf(address account) external view returns (uint256)",
      "function allowance(address owner, address spender) external view returns (uint256)"
    ];

    // Get the ERC20 token contract
    const srcToken = new ethers.Contract(sellToken, ERC20_ABI, user);
    // Approve srcToken to swapper
    await srcToken.connect(owner).approve(swapper.target, dummyAmount);
    console.log("Approved tokens to swapper", dummyAmount.toString());

    const sellAmount = amount.toString();
    const apiKey = "03b24686-4712-4e62-a5ba-571b6ca9c61c";

    const response = await fetch(`https://sepolia.api.0x.org/swap/v1/quote?buyToken=${buyToken}&sellAmount=${sellAmount}&sellToken=${sellToken}&excludedSources=0x,Kyber`, {
      headers: {
        '0x-api-key': apiKey
      }
    });

    if (!response.ok) {
      throw new Error(`Failed to fetch quote: ${response.statusText}`);
    }

    const quoteData = await response.json();
    const { data } = quoteData;

    const abiCoder = new ethers.AbiCoder();
    const encodedData = abiCoder.encode(
      ["address", "address", "uint256", "bytes"],
      [sellToken, buyToken, dummyAmount, data]
    );

    return { encodedData, srcToken };
  }


  it("should set the newExchange address", async function () {
    this.timeout(60000)
    newExchangeAddress = "0xDef1C0ded9bec7F1a1670819833240f027b25EfF";

    // Set newExchange address
    const tx = await swapper.connect(owner).setNewExchange(newExchangeAddress);
    await tx.wait();

    // Get the newExchange address from the contract
    const storedNewExchangeAddress = await swapper.newExchange();
    console.log("Stored newExchange address in Swapper:", storedNewExchangeAddress);

    // Assert the newExchange address is as expected
    expect(storedNewExchangeAddress).to.equal(newExchangeAddress);
  });

  it("Should swap tokens as expected", async function () {
    const amount = ethers.parseEther("0.01");
    const buyToken = '0xe1ec108ba9fb9b8a691848d9c5a34aa5fbaa6e23';

    try {
      const { encodedData, srcToken } = await performSwap(sellTokenAddress, buyToken, amount, owner.address);

      // before swap amount
      const beforeSwapAmount = await srcToken.balanceOf(owner.address);
      console.log("Before swap amount:", beforeSwapAmount.toString());

      // this.timeout(60000);
      // Perform the swap transaction
      const swapTx = await swapper.connect(owner).swap(encodedData, owner.address);

      // Wait for the transaction to be mined
      await swapTx.wait();

      console.log("tx hash:", swapTx.hash);

      // after swap amount
      const afterSwapAmount = await srcToken.balanceOf(owner.address);
      console.log("After swap amount:", afterSwapAmount.toString());
      console.log("Swap was Successfull");

    } catch (error) {
      console.error("Swap failed:", error.message);
      expect.fail("Swap transaction should succeed");
    }
  });

  it("should lock tokens", async function () {
    const buyToken = '0xe1ec108ba9fb9b8a691848d9c5a34aa5fbaa6e23';
  
    const amount = ethers.parseEther("0.01");

    try {
      const { encodedData, srcToken } = await performSwap(sellTokenAddress, buyToken, amount, owner.address);

      // Before Lock amount
      const beforeLockAmount = await srcToken.balanceOf(owner.address);
      console.log("Before Lock amount:", beforeLockAmount.toString());

      // Call the lock function on the swapper contract
      const lockTx = await swapper.connect(owner).swap(encodedData, owner.address);
      await lockTx.wait();

      lockTxHash = lockTx.hash;

      // After Lock amount
      const afterLockAmount = await srcToken.balanceOf(owner.address);
      console.log("After Lock amount:", afterLockAmount.toString());

      // Get the balance of sellToken in the swapper contract
      const swapperBalance = await swapper.getBalance(buyToken);
      console.log("Swapper's sellToken balance:", swapperBalance.toString());

      console.log("lockTx:", lockTx.hash, "Lock token is successfull");

    } catch (error) {
      console.error("Lock failed:", error.message);
      // expect.fail("Lock transaction should succeed");
    }
  });

  // // now testing with corner cases
  it("Test with dummy calldata in lock tokens", async function () {
    const buyToken = '0xe1ec108ba9fb9b8a691848d9c5a34aa5fbaa6e23';
    const amount = ethers.parseEther("0.01");
    const dummyAmount = ethers.parseEther("0.04");

    console.log("Generating 0x calldata on Link token to Doge token with 0.01ETH value to lock and deducting 0.04ETH");
    console.log("Deduction amount", dummyAmount);
    console.log("Actual value sent to 0x to swap", amount);

    try {
      const { encodedData, srcToken } = await generatingDummydata(sellTokenAddress, buyToken, amount, owner.address, dummyAmount);

      // Before Lock amount
      const beforeLockAmount = await srcToken.balanceOf(owner.address);
      console.log("Before Lock amount:", beforeLockAmount.toString());

      // Call the lock function on the swapper contract
      const lockTx = await swapper.connect(owner).swap(encodedData, owner.address);
      await lockTx.wait();

      lockTxHash = lockTx.hash;

      // After Lock amount
      const afterLockAmount = await srcToken.balanceOf(owner.address);
      console.log("After Lock amount:", afterLockAmount.toString());

      // Get the balance of sellToken in the swapper contract
      const swapperBalance = await swapper.getBalance(buyToken);
      console.log("Swapper's sellToken balance:", swapperBalance.toString());

      console.log("lockTx:", lockTx.hash);
      console.log("Hence Large amount locked from user is Stuck in contract now only admin can widthdraw it to BridgeAdmin Addrss");

    } catch (error) {
      console.error("Lock failed:", error.message);
      // expect.fail("Lock transaction should succeed");
    }
  });


  it("Must Fail Test with dummy calldata in lock tokens with smaller lock value and sending larger value", async function () {
    const buyToken = '0xe1ec108ba9fb9b8a691848d9c5a34aa5fbaa6e23';
    const amount = ethers.parseEther("0.3");
    const dummyAmount = ethers.parseEther("0.01");

    console.log("Generating 0x calldata on Link token to Doge token with 0.3ETH value to lock and deducting 0.01ETH");
    console.log("Deduction amount", dummyAmount);
    console.log("Actual value sent to 0x to swap", amount);
    console.log("Here the dummy Amount is Smaller than actual deduction amount, so approval will only given for smller value, hence this test will fail");
    try {
      const { encodedData, srcToken } = await generatingDummydata(sellTokenAddress, buyToken, amount, owner.address, dummyAmount);

      // Before Lock amount
      const beforeLockAmount = await srcToken.balanceOf(owner.address);
      console.log("Before Lock amount:", beforeLockAmount.toString());

      // Call the lock function on the swapper contract
      const lockTx = await swapper.connect(owner).swap(encodedData, owner.address);
      await lockTx.wait();

      lockTxHash = lockTx.hash;

      // After Lock amount
      const afterLockAmount = await srcToken.balanceOf(owner.address);
      console.log("After Lock amount:", afterLockAmount.toString());

      // Get the balance of sellToken in the swapper contract
      const swapperBalance = await swapper.getBalance(buyToken);
      console.log("Swapper's sellToken balance:", swapperBalance.toString());

      console.log("lockTx:", lockTx.hash);
      console.log("Hence Large amount locked from user is Stuck in contract now only admin can widthdraw it to BridgeAdmin Addrss");

    } catch (error) {
      console.error("Lock failed:", error.message);
      console.log("It will fail because in 0x the we have passed larger value and we are approving smaller value as per calldata")
      // expect.fail("Lock transaction should succeed");
    }
  });



  it("Should swap tokens as expected invalid tokens", async function () {
    const amount = ethers.parseEther("0.1");
    const invalidSellToken = '0x0000000000000000000000000000000000000000';
    const buyToken = '0xe1ec108ba9fb9b8a691848d9c5a34aa5fbaa6e23';
    try {
      const fetch = (await import('node-fetch')).default;
      const sellAmount = amount.toString();
      const apiKey = "03b24686-4712-4e62-a5ba-571b6ca9c61c";
      const response = await fetch(`https://sepolia.api.0x.org/swap/v1/quote?buyToken=${buyToken}&sellAmount=${sellAmount}&sellToken=${sellTokenAddress}&excludedSources=0x,Kyber`, {
        headers: {
          '0x-api-key': apiKey
        }
      });
      if (!response.ok) {
        throw new Error(`Failed to fetch quote: ${response.statusText}`);
      }
      const quoteData = await response.json();
      const { data } = quoteData;
      const abiCoder = new ethers.AbiCoder();
      const encodedData = abiCoder.encode(
        ["address", "address", "uint256", "bytes"],
        [invalidSellToken, buyToken, amount, data]
      );
      //  this.timeout(60000);
      // Perform the swap transaction
      const swapTx = await swapper.connect(owner).swap(encodedData, owner.address);
      // Wait for the transaction to be mined

      await swapTx.wait();

      console.log("Transaction hash:", swapTx.hash);
      console.log("Swap was successful");
    } catch (error) {

      console.error("Swap failed:", error.message);

    }

  });



  it("Should swap tokens as expected same SellToken and different BuyToken", async function () {
    const amount = ethers.parseEther("0.1");
    const buyToken = '0xe1ec108ba9fb9b8a691848d9c5a34aa5fbaa6e23';
    const invalidBuyToken = '0x0000000000000000000000000000000000000000';
    try {
      const fetch = (await import('node-fetch')).default;
      const sellAmount = amount.toString();
      const apiKey = "03b24686-4712-4e62-a5ba-571b6ca9c61c";
      const response = await fetch(`https://sepolia.api.0x.org/swap/v1/quote?buyToken=${buyToken}&sellAmount=${sellAmount}&sellToken=${sellTokenAddress}&excludedSources=0x,Kyber`, {
        headers: {
          '0x-api-key': apiKey
        }

      });
      if (!response.ok) {
        throw new Error(`Failed to fetch quote: ${response.statusText}`);
      }
      const quoteData = await response.json();
      const { data } = quoteData;
      const abiCoder = new ethers.AbiCoder();
      const encodedData = abiCoder.encode(
        ["address", "address", "uint256", "bytes"],
        [sellTokenAddress, invalidBuyToken, amount, data]
      );
       this.timeout(60000);

      // Perform the swap transaction
      const swapTx = await swapper.connect(owner).swap(encodedData, owner.address);
      // Wait for the transaction to be mined
      await swapTx.wait();
      console.log("Transaction hash:", swapTx.hash);
      console.log("Swap was successful");
    } catch (error) {
      console.error("Swap failed:", error.message);
    }

  });



  it("Should swap tokens as expected no callData", async function () {

    const amount = ethers.parseEther("0.1");

    const buyToken = '0xe1ec108ba9fb9b8a691848d9c5a34aa5fbaa6e23';



    try {

      const fetch = (await import('node-fetch')).default;



      const sellAmount = amount.toString();

      const apiKey = "03b24686-4712-4e62-a5ba-571b6ca9c61c";



      const response = await fetch(`https://sepolia.api.0x.org/swap/v1/quote?buyToken=${buyToken}&sellAmount=${sellAmount}&sellToken=${sellTokenAddress}&excludedSources=0x,Kyber`, {

        headers: {

          '0x-api-key': apiKey

        }

      });

      if (!response.ok) {
        throw new Error(`Failed to fetch quote: ${response.statusText}`);
      }
      const quoteData = await response.json();
      const { data } = quoteData;
      const abiCoder = new ethers.AbiCoder();
      const encodedData = abiCoder.encode(
        ["address", "address", "uint256", "bytes"],

        [sellTokenAddress, invalidBuyToken, amount, data]
      );
      this.timeout(60000);
      // Perform the swap transaction
      const swapTx = await swapper.connect(owner).swap("0x", owner.address);
      // Wait for the transaction to be mined
      await swapTx.wait();
      console.log("Transaction hash:", swapTx.hash);
      console.log("Swap was successful");
    } catch (error) {
      console.error("Swap failed:", error.message);
    }

  });



});