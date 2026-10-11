// EIP-6963: discover every injected wallet instead of assuming window.ethereum.
import type { Eip1193Provider } from "ethers";

export interface WalletInfo {
  uuid: string;   // unique per page load
  name: string;   // e.g. "MetaMask"
  icon: string;   // data URI
  rdns: string;   // reverse domain name, e.g. "io.metamask"
}
export interface WalletDetail {
  info: WalletInfo;
  provider: Eip1193Provider & {
    on?: (event: string, handler: (...args: unknown[]) => void) => void;
    removeListener?: (event: string, handler: (...args: unknown[]) => void) => void;
  };
}

/** Calls onWallet once per wallet that announces itself. Returns an unsubscribe. */
export function discoverWallets(onWallet: (w: WalletDetail) => void): () => void {
  const seen = new Set<string>();
  const handler = (event: Event) => {
    const detail = (event as CustomEvent<WalletDetail>).detail;
    if (!seen.has(detail.info.uuid)) {
      seen.add(detail.info.uuid);
      onWallet(detail);
    }
  };
  window.addEventListener("eip6963:announceProvider", handler);
  window.dispatchEvent(new Event("eip6963:requestProvider"));
  // Fallback for wallets that only support the older window.ethereum injection.
  const injected = window as unknown as { ethereum?: WalletDetail["provider"] };
  const legacy = injected.ethereum;
  if (legacy) {
    setTimeout(() => {
      if (seen.size === 0) {
        onWallet({
          info: { uuid: "legacy", name: "Browser wallet", icon: "", rdns: "" },
          provider: legacy,
        });
      }
    }, 300);
  }
  return () => window.removeEventListener("eip6963:announceProvider", handler);
}
