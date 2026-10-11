// Connect to the wallet the user picked, and follow account and network changes.
import { useCallback, useEffect, useState } from "react";
import { BrowserProvider, type JsonRpcSigner } from "ethers";
import type { WalletDetail } from "../lib/wallets";
import { ensureNetwork } from "../lib/network";

export function useWallet() {
  const [wallet, setWallet] = useState<WalletDetail | null>(null);
  const [signer, setSigner] = useState<JsonRpcSigner | null>(null);
  const [account, setAccount] = useState<string | null>(null);

  const connect = useCallback(async (w: WalletDetail) => {
    await w.provider.request({ method: "eth_requestAccounts" });
    await ensureNetwork(w.provider);
    // A fresh BrowserProvider after every switch: ethers providers are per-network.
    const provider = new BrowserProvider(w.provider);
    const s = await provider.getSigner();
    setWallet(w);
    setSigner(s);
    setAccount(await s.getAddress());
  }, []);

  useEffect(() => {
    if (!wallet?.provider.on) return;
    const reconnect = () => { void connect(wallet); };
    const onAccounts = (accounts: unknown) => {
      if ((accounts as string[]).length === 0) {   // user disconnected the site
        setSigner(null); setAccount(null);
      } else reconnect();
    };
    wallet.provider.on("accountsChanged", onAccounts);
    wallet.provider.on("chainChanged", reconnect);
    return () => {
      wallet.provider.removeListener?.("accountsChanged", onAccounts);
      wallet.provider.removeListener?.("chainChanged", reconnect);
    };
  }, [wallet, connect]);

  return { wallet, signer, account, connect };
}
