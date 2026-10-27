// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title GlobalRunMedal
 * @dev Standar NFT ERC-721 untuk Medali Digital Kompetisi Atletik GlobalRun di Polygon.
 */
contract GlobalRunMedal {
    string public name = "GlobalRun Athlete Medal";
    string public symbol = "GRMEDAL";

    address public owner;
    uint256 private _nextTokenId = 1;

    struct MedalMetadata {
        uint256 tokenId;
        string participantName;
        string raceId;
        string raceTitle;
        uint256 distanceMeters;
        uint256 durationSeconds;
        uint256 avgSpeedKmhTimes100; // e.g. 10.75 km/h -> 1075
        string tier;                 // GOLD, SILVER, BRONZE
        string localBlockHash;       // SHA-256 local ledger hash
        uint256 timestamp;
    }

    struct MintParams {
        address recipient;
        string participantName;
        string raceId;
        string raceTitle;
        uint256 distanceMeters;
        uint256 durationSeconds;
        uint256 avgSpeedKmhTimes100;
        string tier;
        string localBlockHash;
    }

    mapping(uint256 => address) private _owners;
    mapping(address => uint256) private _balances;
    mapping(uint256 => MedalMetadata) public medals;
    mapping(string => bool) public isHashMinted;

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event MedalMinted(
        uint256 indexed tokenId,
        address indexed recipient,
        string raceTitle,
        string tier,
        string localBlockHash
    );

    modifier onlyOwner() {
        require(msg.sender == owner, "Only relayer owner can call this");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function totalSupply() external view returns (uint256) {
        return _nextTokenId - 1;
    }

    function ownerOf(uint256 tokenId) public view returns (address) {
        address tokenOwner = _owners[tokenId];
        require(tokenOwner != address(0), "Token does not exist");
        return tokenOwner;
    }

    function balanceOf(address account) external view returns (uint256) {
        require(account != address(0), "Zero address query");
        return _balances[account];
    }

    /**
     * @dev Minting Medali NFT Baru On-Chain di Polygon Amoy
     */
    function mintMedal(MintParams calldata p) external onlyOwner returns (uint256) {
        require(p.recipient != address(0), "Invalid recipient");
        require(!isHashMinted[p.localBlockHash], "Medal already minted for this run");

        uint256 tokenId = _nextTokenId++;
        _owners[tokenId] = p.recipient;
        _balances[p.recipient] += 1;
        isHashMinted[p.localBlockHash] = true;

        medals[tokenId] = MedalMetadata({
            tokenId: tokenId,
            participantName: p.participantName,
            raceId: p.raceId,
            raceTitle: p.raceTitle,
            distanceMeters: p.distanceMeters,
            durationSeconds: p.durationSeconds,
            avgSpeedKmhTimes100: p.avgSpeedKmhTimes100,
            tier: p.tier,
            localBlockHash: p.localBlockHash,
            timestamp: block.timestamp
        });

        emit Transfer(address(0), p.recipient, tokenId);
        emit MedalMinted(tokenId, p.recipient, p.raceTitle, p.tier, p.localBlockHash);

        return tokenId;
    }

    function getMedal(uint256 tokenId) external view returns (MedalMetadata memory) {
        require(_owners[tokenId] != address(0), "Token does not exist");
        return medals[tokenId];
    }
}
