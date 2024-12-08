# Contract to clone project YinYang

- It is a dual token system with 2 tokens: YIN and YANG

# How to clone?

How to run?

- Deploy YIN contract and save it's CA
- Deploy YANG contract with YIN's CA as input
- setYangContract (in YIN contract)
- Set and lock price factors
- - \_growthrate = 10 and \_priceFactors = [5,4,3,2];
- - lockPriceFactors
- doCreateBlock

Example with multiple growthrates!

- setPriceFactors(2850, [37322249, 36035043, 34833666, 33709810]); // Set price factors for 2850
- setPriceFactors(1800, [37000000, 36000000, 35000000, 34000000]); // Set price factors for 1800
- setPriceFactors(900, [36500000, 35500000, 34500000, 33500000]); // Set price factors for 900
- setPriceFactors(400, [36000000, 35000000, 34000000, 33000000]); // Set price factors for 400
