const { ethers } = require('ethers');
require('dotenv').config({ path: require('path').join(__dirname, '../../.env') });

async function checkBalance() {
  const rpcUrl = process.env.POLYGON_RPC_URL || 'https://polygon-amoy.drpc.org';
  const address = process.env.POLYGON_ADMIN_ADDRESS;

  if (!address) {
    console.error('Alamat wallet belum diatur di .env!');
    process.exit(1);
  }

  console.log(`Menghubungkan ke Polygon Amoy (${rpcUrl})...`);
  const provider = new ethers.JsonRpcProvider(rpcUrl, 80002, { staticNetwork: true });

  try {
    const balanceWei = await provider.getBalance(address);
    const balancePol = ethers.formatEther(balanceWei);

    console.log('==================================================');
    console.log(`Alamat Wallet Admin: ${address}`);
    console.log(`Saldo Saat Ini      : ${balancePol} POL`);
    console.log('==================================================');

    if (parseFloat(balancePol) > 0) {
      console.log('✅ Saldo mencukupi untuk deploy & minting medali!');
      return true;
    } else {
      console.log('⚠️ Saldo masih 0 POL.');
      console.log('Silakan klaim saldo testnet gratis di Faucet.');
      return false;
    }
  } catch (error) {
    console.error('Gagal mengecek saldo:', error.message);
    return false;
  }
}

if (require.main === module) {
  checkBalance();
}

module.exports = { checkBalance };
