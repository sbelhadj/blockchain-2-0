import { useEffect, useState } from "react";
import { discoverWallets, type WalletDetail } from "../lib/wallets";

export function WalletPicker({ onPick }: { onPick: (w: WalletDetail) => void }) {
  const [wallets, setWallets] = useState<WalletDetail[]>([]);
  useEffect(() => discoverWallets((w) => setWallets((list) => [...list, w])), []);

  if (wallets.length === 0) return <p>No wallet found. Install one and reload.</p>;
  return (
    <div className="wallets">
      {wallets.map((w) => (
        <button key={w.info.uuid} onClick={() => onPick(w)}>
          {w.info.icon && <img src={w.info.icon} alt="" width={20} height={20} />}
          Connect {w.info.name}
        </button>
      ))}
    </div>
  );
}
