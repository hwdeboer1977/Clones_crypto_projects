const { ethers } = require("ethers");
const ABI = require("./abis/ABI.json");

const provider = new ethers.providers.JsonRpcProvider(
  "https://bsc-dataseed1.binance.org:443"
);

const contractAddress = "0xee43d9f2c068bfa67726f78dd17da5443d9fcd03";

const contract = new ethers.Contract(contractAddress, ABI, provider);
console.log(contract);

// Method 1 to call Solidity function
async function getTotalSupply() {
  try {
    // Call the totalSupply function and await the result
    const supply = await contract.totalSupply();

    // Log the result
    console.log("Total Supply:", supply.toString()); // toString() to convert BigNumber to string
  } catch (error) {
    console.error("Error calling totalSupply:", error);
  }
}

//getTotalSupply();

// Method 2 to call Solidity function
// Now you can call functions, like:
contract
  .totalSupply()
  .then((supply) => {
    console.log(supply.toString()); // Log the total supply (converted to string if it's a BigNumber)
  })
  .catch((error) => {
    console.error("Error:", error);
  });

// Hours since epoch
const hourstoepoch = Math.floor(Date.now() / 1000 / 3600);
console.log(hourstoepoch);

// Block Timestamp (block.timestamp): This is a Unix timestamp that
// represents the time when the current block was mined, measured in seconds
// since January 1, 1970 (the Unix epoch). It's used for time-based operations in smart contracts.
async function getBlockTimestamp() {
  const latestBlock = await provider.getBlock("latest");
  console.log("Block Number:", latestBlock.number);
  console.log("Block Timestamp:", latestBlock.timestamp);
}

getBlockTimestamp();
