const { ethers } = require('ethers');
const path = require('path');
const fs = require('fs');
require('dotenv').config({ path: path.join(__dirname, '../../.env') });

class PolygonService {
  constructor() {
    this.rpcUrl = process.env.POLYGON_RPC_URL || 'https://polygon-amoy.drpc.org';
    this.chainId = 80002;
    this.contractAddress = process.env.MEDAL_CONTRACT_ADDRESS || null;
    this.privateKey = process.env.POLYGON_ADMIN_PRIVATE_KEY || null;

    this.provider = new ethers.JsonRpcProvider(this.rpcUrl, this.chainId, { staticNetwork: true });

    if (this.privateKey) {
      this.wallet = new ethers.Wallet(this.privateKey, this.provider);
      this.adminAddress = this.wallet.address;
    } else {
      this.wallet = null;
      this.adminAddress = null;
    }

    const abiPath = path.join(__dirname, '../contracts/GlobalRunMedalAbi.json');
    if (fs.existsSync(abiPath)) {
      this.abi = JSON.parse(fs.readFileSync(abiPath, 'utf8'));
    } else {
      this.abi = null;
    }
  }

  getContract() {
    this.contractAddress = process.env.MEDAL_CONTRACT_ADDRESS || this.contractAddress;
    if (!this.contractAddress || !this.wallet || !this.abi) {
      return null;
    }
    return new ethers.Contract(this.contractAddress, this.abi, this.wallet);
  }

  async getWalletInfo() {
    if (!this.adminAddress) {
      return { address: null, balancePol: '0.0', isContractDeployed: false };
    }

    try {
      const balanceWei = await this.provider.getBalance(this.adminAddress);
      const balancePol = ethers.formatEther(balanceWei);
      const isContractDeployed = !!(process.env.MEDAL_CONTRACT_ADDRESS || this.contractAddress);

      return {
        address: this.adminAddress,
        balancePol,
        contractAddress: process.env.MEDAL_CONTRACT_ADDRESS || this.contractAddress,
        isContractDeployed,
        network: 'Polygon Amoy Testnet (Chain ID 80002)',
        explorerUrl: `https://amoy.polygonscan.com/address/${this.adminAddress}`,
      };
    } catch (error) {
      return {
        address: this.adminAddress,
        balancePol: '0.0',
        error: error.message,
      };
    }
  }

  async mintMedalOnline({
    recipient,
    participantName,
    raceId,
    raceTitle,
    distanceKm,
    durationSeconds,
    avgSpeedKmh,
    tier,
    localBlockHash,
  }) {
    const contract = this.getContract();
    if (!contract) {
      throw new Error(
        'Smart contract belum dideploy atau konfigurasi wallet admin belum lengkap di .env'
      );
    }

    // Default recipient to admin if runner doesn't have an Ethereum address
    const targetRecipient =
      recipient && ethers.isAddress(recipient) ? recipient : this.adminAddress;

    const distanceMeters = Math.round(Number(distanceKm || 0) * 1000);
    const duration = Math.round(Number(durationSeconds || 0));
    const speedX100 = Math.round(Number(avgSpeedKmh || 0) * 100);

    const mintParams = {
      recipient: targetRecipient,
      participantName: String(participantName || 'Virtual Runner'),
      raceId: String(raceId || 'race-0'),
      raceTitle: String(raceTitle || 'Global Virtual Race'),
      distanceMeters,
      durationSeconds: duration,
      avgSpeedKmhTimes100: speedX100,
      tier: String(tier || 'BRONZE'),
      localBlockHash: String(localBlockHash || '0x0'),
    };

    console.log(`[Polygon Relayer] Mengirim transaksi minting ke smart contract (${this.contractAddress})...`);
    const tx = await contract.mintMedal(mintParams);
    console.log(`[Polygon Relayer] Tx submitted: ${tx.hash}. Menunggu konfirmasi...`);

    const receipt = await tx.wait(1);

    const polygonscanUrl = `https://amoy.polygonscan.com/tx/${tx.hash}`;
    console.log(`[Polygon Relayer] Sukses! Verified on-chain: ${polygonscanUrl}`);

    return {
      success: true,
      txHash: tx.hash,
      blockNumber: receipt.blockNumber,
      contractAddress: this.contractAddress,
      polygonscanUrl,
    };
  }
}

module.exports = new PolygonService();
