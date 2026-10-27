const fs = require('fs');
const path = require('path');
const solc = require('solc');
const { ethers } = require('ethers');
require('dotenv').config({ path: path.join(__dirname, '../../.env') });

function compileContract() {
  console.log('[1/4] Mengompilasi Smart Contract GlobalRunMedal.sol...');
  const contractPath = path.join(__dirname, '../contracts/GlobalRunMedal.sol');
  const source = fs.readFileSync(contractPath, 'utf8');

  const input = {
    language: 'Solidity',
    sources: {
      'GlobalRunMedal.sol': {
        content: source,
      },
    },
    settings: {
      viaIR: true,
      optimizer: {
        enabled: true,
        runs: 200,
      },
      outputSelection: {
        '*': {
          '*': ['abi', 'evm.bytecode'],
        },
      },
    },
  };

  const output = JSON.parse(solc.compile(JSON.stringify(input)));

  if (output.errors) {
    const errors = output.errors.filter((e) => e.severity === 'error');
    if (errors.length > 0) {
      console.error('Kompilasi gagal:', errors);
      process.exit(1);
    }
  }

  const contractObj = output.contracts['GlobalRunMedal.sol']['GlobalRunMedal'];
  const abi = contractObj.abi;
  const bytecode = contractObj.evm.bytecode.object;

  const abiPath = path.join(__dirname, '../contracts/GlobalRunMedalAbi.json');
  fs.writeFileSync(abiPath, JSON.stringify(abi, null, 2), 'utf8');
  console.log('✅ Kompilasi sukses! ABI tersimpan di GlobalRunMedalAbi.json');

  return { abi, bytecode };
}

async function deploy() {
  const { abi, bytecode } = compileContract();

  const rpcUrl = process.env.POLYGON_RPC_URL || 'https://polygon-amoy.drpc.org';
  const privateKey = process.env.POLYGON_ADMIN_PRIVATE_KEY;

  if (!privateKey) {
    console.error('Kunci privat wallet admin belum disetel!');
    process.exit(1);
  }

  console.log('[2/4] Menghubungkan ke Polygon Amoy Network...');
  const provider = new ethers.JsonRpcProvider(rpcUrl, 80002, { staticNetwork: true });
  const wallet = new ethers.Wallet(privateKey, provider);

  const balance = await provider.getBalance(wallet.address);
  console.log(`Alamat Deployer: ${wallet.address}`);
  console.log(`Saldo Wallet   : ${ethers.formatEther(balance)} POL`);

  if (balance === 0n) {
    console.log('\n==================================================');
    console.log('⚠️ SALDO WALLET ADMIN MASIH 0 POL');
    console.log('Untuk mendistribusikan medali on-chain di Polygon Amoy:');
    console.log('1. Salin alamat: ' + wallet.address);
    console.log('2. Buka Faucet: https://faucet.polygon.technology/');
    console.log('3. Tempelkan alamat di atas dan klaim token POL gratis.');
    console.log('==================================================\n');
    process.exit(0);
  }

  console.log('[3/4] Mengirim transaksi deployment ke Polygon Amoy (Testnet)...');
  const factory = new ethers.ContractFactory(abi, bytecode, wallet);
  const contract = await factory.deploy();

  console.log(`Menunggu konfirmasi block... (TxHash: ${contract.deploymentTransaction().hash})`);
  await contract.waitForDeployment();

  const contractAddress = await contract.getAddress();
  console.log('\n==================================================');
  console.log('🎉 SMART CONTRACT BERHASIL DIDEPLOY KE POLYGON!');
  console.log(`Alamat Kontrak : ${contractAddress}`);
  console.log(`Polygonscan URL: https://amoy.polygonscan.com/address/${contractAddress}`);
  console.log('==================================================\n');

  // Simpan alamat kontrak ke .env
  const envPath = path.join(__dirname, '../../.env');
  let envContent = fs.readFileSync(envPath, 'utf8');
  if (envContent.includes('MEDAL_CONTRACT_ADDRESS=')) {
    envContent = envContent.replace(/MEDAL_CONTRACT_ADDRESS=.*/, `MEDAL_CONTRACT_ADDRESS=${contractAddress}`);
  } else {
    envContent += `\nMEDAL_CONTRACT_ADDRESS=${contractAddress}\n`;
  }
  fs.writeFileSync(envPath, envContent, 'utf8');
  console.log('[4/4] MEDAL_CONTRACT_ADDRESS berhasil disimpan di backend/.env');

  return contractAddress;
}

if (require.main === module) {
  deploy().catch((err) => {
    console.error('Error saat deploy:', err);
    process.exit(1);
  });
}

module.exports = { deploy, compileContract };
