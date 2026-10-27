const { ethers } = require('ethers');
const fs = require('fs');
const path = require('path');

const envPath = path.join(__dirname, '../../.env');

function generateOrGetWallet() {
  let envContent = '';
  if (fs.existsSync(envPath)) {
    envContent = fs.readFileSync(envPath, 'utf8');
  }

  // Check if wallet already exists
  const addressMatch = envContent.match(/POLYGON_ADMIN_ADDRESS=(0x[a-fA-F0-9]{40})/);
  const keyMatch = envContent.match(/POLYGON_ADMIN_PRIVATE_KEY=(0x[a-fA-F0-9]{64}|[a-fA-F0-9]{64})/);

  let wallet;
  if (addressMatch && keyMatch) {
    wallet = new ethers.Wallet(keyMatch[1]);
    console.log('\n[INFO] Menggunakan Wallet Admin Relayer yang sudah ada:');
  } else {
    // Generate new random wallet
    wallet = ethers.Wallet.createRandom();
    console.log('\n[INFO] Berhasil membuat Wallet Admin Relayer BARU:');

    let appendText = `\n# Polygon Amoy Blockchain Relayer\nPOLYGON_ADMIN_ADDRESS=${wallet.address}\nPOLYGON_ADMIN_PRIVATE_KEY=${wallet.privateKey}\nPOLYGON_RPC_URL=https://rpc-amoy.polygon.technology/\nPOLYGON_CHAIN_ID=80002\n`;
    fs.appendFileSync(envPath, appendText, 'utf8');
    console.log('[OK] Kunci privat dan alamat aman tersimpan di backend/.env');
  }

  console.log('==================================================');
  console.log('ALAMAT WALLET ADMIN (POLYGON AMOY TESTNET):');
  console.log(wallet.address);
  console.log('==================================================\n');

  return wallet.address;
}

if (require.main === module) {
  generateOrGetWallet();
}

module.exports = { generateOrGetWallet };
