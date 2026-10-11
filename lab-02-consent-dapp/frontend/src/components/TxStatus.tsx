import type { TxState } from "../lib/txMachine";

const explorer = (hash: string) => `https://sepolia.etherscan.io/tx/${hash}`;

export function TxStatus({ tx, onClose }: { tx: TxState; onClose: () => void }) {
  switch (tx.status) {
    case "idle":
      return null;
    case "awaiting-signature":
      return <p className="tx info">{tx.label}: confirm in your wallet...</p>;
    case "pending":
      return <p className="tx info">{tx.label}: waiting for a block.{" "}
        <a href={explorer(tx.hash)} target="_blank" rel="noreferrer">View</a></p>;
    case "confirmed":
      return <p className="tx ok">{tx.label}: confirmed in block {tx.block}.{" "}
        <button onClick={onClose}>OK</button></p>;
    case "rejected":
      return <p className="tx warn">{tx.label}: cancelled in the wallet.{" "}
        <button onClick={onClose}>OK</button></p>;
    case "failed":
      return <p className="tx error">{tx.label} failed: {tx.reason}{" "}
        <button onClick={onClose}>OK</button></p>;
  }
}
