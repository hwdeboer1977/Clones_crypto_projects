# Contract to clone project Centric

- See website for more information: https://www.centric.com/
- It is a dual token system with 2 tokens: CNR and CNS

# More information on cloned contract:

- Deployed with the following wallet: 0x7C03A3238C4A53bC87673e093Ffc0185866909Dd
- Deployed contract (CentricSwap): https://bscscan.com/token/0xdf8afd53bc1fbbae3e2286fe94b869b28167d5f0
- Deployed contract (CentricRise): https://bscscan.com/token/0x8c93f9ac3b5ed5415b9a5887e4a6cbd261d028e2

# How to clone?

- Deploy centricSwap.sol
- Use setRiceContract function with CNS contract as input
- Deploy centricRise.sol, with mintsaver and swapcontract as inputs
- setPriceFactors
- lockPriceFactors
- Note: if you lock the price factors, you also lock the growthrate. So better to lock different price factors for different growth rates
- doCreateBlock(): insert number: getCurrentHour() + 1
- You need to create several blocks at the same time: every hour CNR goes up.

Example with multiple growthrates!

- setPriceFactors(2850, [37322249, 36035043, 34833666, 33709810]); // Set price factors for 2850
- setPriceFactors(1800, [37000000, 36000000, 35000000, 34000000]); // Set price factors for 1800
- setPriceFactors(900, [36500000, 35500000, 34500000, 33500000]); // Set price factors for 900
- setPriceFactors(400, [36000000, 35000000, 34000000, 33000000]); // Set price factors for 400
