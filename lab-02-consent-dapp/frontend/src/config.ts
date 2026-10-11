// Network and contract settings, read from .env.local (see .env.example).
export const CHAIN_ID = BigInt(import.meta.env.VITE_CHAIN_ID ?? "11155111");
export const CHAIN_NAME = import.meta.env.VITE_CHAIN_NAME ?? "Sepolia";
export const RPC_URL =
  import.meta.env.VITE_RPC_URL ?? "https://ethereum-sepolia-rpc.publicnode.com";
export const CONSENT_ADDRESS = import.meta.env.VITE_CONSENT_ADDRESS ?? "";
export const DEPLOY_BLOCK = Number(import.meta.env.VITE_DEPLOY_BLOCK ?? "0");
