// Lab 2, Part D step 3 (Exercise 4.4): revoke through the state machine.
import type { Contract } from "ethers";
import { useTx } from "../hooks/useTx";
import { TxStatus } from "./TxStatus";

export function RevokeButton({ writer, id }: { writer: Contract; id: bigint }) {
  const { tx, run, reset } = useTx();
  const busy = tx.status === "awaiting-signature" || tx.status === "pending";
  return (
    <>
      <button
        disabled={busy}
        onClick={() =>
          run(
            "Revoke consent",
            () => writer.revokeConsent.estimateGas(id),
            () => writer.revokeConsent(id),
          )
        }
      >
        Revoke
      </button>
      <TxStatus tx={tx} onClose={reset} />
    </>
  );
}
