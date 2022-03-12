## security test

for security static test run the following command:

```
virtualenv  -p python3 venv

pip3 install -r requirements.txt

source venv/bin/activate

first use flatten to collect all file in one file
and clean the file (remove extra SPDX move error from source to here)

slither src/contracts/example_merged.sol

myth a src/contracts/example.sol

```

---

we should use `Goerli` as testnet
(because it is the only mainnet will be remain functional in post-merge world)

---

for local test with HardHat

```
npx hardhat run scripts/deploy.ts --network localhost
npx hardhat console --network localhost

const SampleContract = await ethers.getContractFactory('SampleContract');
const sampleContractInstance = await Greeter.attach(ContractAddress);

await sampleContractInstance.changeStateMethod(some input);
```

---

for running solidity linter run the following command:

```
 npx solhint src/contracts/example.sol --fix
```

---

TODO: active SARIF in slither github action after publicizing the repo

---

for exporting abi

```
npx hardhat export-abi
```
