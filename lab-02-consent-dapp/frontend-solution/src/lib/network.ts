// Make sure the wallet is on the network the dApp expects.
import type { Eip1193Provider } from "ethers";
import { CHAIN_ID, CHAIN_NAME, RPC_URL } from "../config";

const hexChainId = "0x" + CHAIN_ID.toString(16);

export async function ensureNetwork(wallet: Eip1193Provider): Promise<void> {
  const current = (await wallet.request({ method: "eth_chainId" })) as string;
  if (BigInt(current) === CHAIN_ID) return;
  try {
    await wallet.request({ method: "wallet_switchEthereumChain",
      params: [{ chainId: hexChainId }] });
  } catch (err) {
    // 4902: the wallet does not know this chain yet, so offer to add it.
    if ((err as { code?: number }).code !== 4902) throw err;
    await wallet.request({ method: "wallet_addEthereumChain", params: [{
      chainId: hexChainId,
      chainName: CHAIN_NAME,
      nativeCurrency: { name: "Ether", symbol: "ETH", decimals: 18 },
      rpcUrls: [RPC_URL],
    }] });
  }
}
