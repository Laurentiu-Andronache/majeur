/**
 * CREATE2 Address Predictor for Moloch (TypeScript)
 *
 * All you need is the implementation addresses - everything else is computed.
 */

import { keccak256, concat, AbiCoder, type AddressLike } from 'ethers';

/**
 * Minimal Proxy Bytecode Pattern (54 bytes total)
 * From Moloch assembly: prefix + implementation + suffix
 */
const PROXY_BYTECODE = {
  prefix: '0x602d5f8160095f39f35f5f365f5f37365f73', // 20 bytes
  suffix: '0x5af43d5f5f3e6029573d5ffd5b3d5ff3',     // 14 bytes
} as const;

/**
 * Build minimal proxy bytecode for an implementation
 */
function buildProxyBytecode(implementation: string): string {
  const impl = implementation.toLowerCase().replace('0x', '');
  return PROXY_BYTECODE.prefix + impl + PROXY_BYTECODE.suffix.replace('0x', '');
}

/**
 * Core CREATE2 formula: keccak256(0xff ++ deployer ++ salt ++ keccak256(bytecode))[12:]
 */
function computeCreate2Address(
  deployer: string,
  salt: string,
  bytecode: string
): string {
  const initCodeHash = keccak256(bytecode);
  const create2Input = concat(['0xff', deployer, salt, initCodeHash]);
  const hash = keccak256(create2Input);
  return '0x' + hash.slice(-40);
}

/**
 * Moloch salt: keccak256(abi.encode(initHolders, initShares, customSalt))
 */
function computeMolochSalt(
  initHolders: string[],
  initShares: string[],
  customSalt: string
): string {
  return keccak256(
    AbiCoder.defaultAbiCoder().encode(
      ['address[]', 'uint256[]', 'bytes32'],
      [initHolders, initShares, customSalt]
    )
  );
}

/**
 * Token salt: bytes32(bytes20(molochAddress))
 * = molochAddress + 24 zero bytes
 */
function computeTokenSalt(molochAddress: string): string {
  const addr = molochAddress.toLowerCase().replace('0x', '');
  return '0x' + addr + '000000000000000000000000';
}

// ============================================================================
// Main API
// ============================================================================

export interface DeploymentConfig {
  /** Deployed Summoner contract address */
  summonerAddress: string;
  /** Moloch implementation address */
  molochImplementation: string;
  /** Shares implementation address */
  sharesImplementation: string;
  /** Badges implementation address */
  badgesImplementation: string;
  /** Loot implementation address */
  lootImplementation: string;
  /** Initial token holders */
  initHolders: string[];
  /** Initial share amounts (in wei, 18 decimals) */
  initShares: string[];
  /** Custom salt for deployment (optional) */
  customSalt?: string;
}

export interface PredictedAddresses {
  moloch: string;
  shares: string;
  badges: string;
  loot: string;
}

/**
 * Predict all deployment addresses for a Moloch DAO
 *
 * @example
 * ```ts
 * const addresses = predictAllAddresses({
 *   summonerAddress: '0x...',
 *   molochImplementation: '0x...',
 *   sharesImplementation: '0x...',
 *   badgesImplementation: '0x...',
 *   lootImplementation: '0x...',
 *   initHolders: ['0x...', '0x...'],
 *   initShares: ['1000000000000000000', '2000000000000000000'],
 *   customSalt: '0x0000...'
 * });
 * ```
 */
export function predictAllAddresses(config: DeploymentConfig): PredictedAddresses {
  const {
    summonerAddress,
    molochImplementation,
    sharesImplementation,
    badgesImplementation,
    lootImplementation,
    initHolders,
    initShares,
    customSalt = '0x0000000000000000000000000000000000000000000000000000000000000000',
  } = config;

  // Predict Moloch DAO
  const molochBytecode = buildProxyBytecode(molochImplementation);
  const molochSalt = computeMolochSalt(initHolders, initShares, customSalt);
  const molochAddress = computeCreate2Address(summonerAddress, molochSalt, molochBytecode);

  // Predict tokens (deployed by Moloch)
  const tokenSalt = computeTokenSalt(molochAddress);

  const sharesAddress = computeCreate2Address(
    molochAddress,
    tokenSalt,
    buildProxyBytecode(sharesImplementation)
  );

  const badgesAddress = computeCreate2Address(
    molochAddress,
    tokenSalt,
    buildProxyBytecode(badgesImplementation)
  );

  const lootAddress = computeCreate2Address(
    molochAddress,
    tokenSalt,
    buildProxyBytecode(lootImplementation)
  );

  return {
    moloch: molochAddress,
    shares: sharesAddress,
    badges: badgesAddress,
    loot: lootAddress,
  };
}

/**
 * React hook for address prediction
 */
export function usePredictDeployment(config: DeploymentConfig | null): PredictedAddresses | null {
  if (!config) return null;

  if (config.initHolders.length !== config.initShares.length) {
    console.error('initHolders and initShares must have same length');
    return null;
  }

  try {
    return predictAllAddresses(config);
  } catch (error) {
    console.error('Error predicting addresses:', error);
    return null;
  }
}

// Export helpers for advanced use
export {
  buildProxyBytecode,
  computeCreate2Address,
  computeMolochSalt,
  computeTokenSalt,
  PROXY_BYTECODE,
};
