// Patient grants consent: estimate gas, send, track every state.
import { useReducer, useState } from "react";
import { isError, type Contract } from "ethers";
import { CATEGORIES, categoryCode, purposeHash, type Category } from "../lib/codes";
import { explainError } from "../lib/errors";
import { txReducer } from "../lib/txMachine";
import { consentInterface } from "../hooks/useConsent";
import { TxStatus } from "./TxStatus";

export function ConsentForm({ writer }: { writer: Contract }) {
  const [provider, setProvider] = useState("");
  const [category, setCategory] = useState<Category>("LAB_RESULTS");
  const [days, setDays] = useState(30);
  const [doc, setDoc] = useState<File | null>(null);
  const [tx, dispatch] = useReducer(txReducer, { status: "idle" });

  async function submit() {
    if (!doc) return;
    // Only the hash leaves the browser; the document itself stays local.
    const hash = purposeHash(new Uint8Array(await doc.arrayBuffer()));
    const args = [provider, categoryCode(category), days, hash] as const;
    dispatch({ type: "start", label: "Grant consent" });
    try {
      // Simulate first: a revert shows up here, before the user pays anything.
      const gas = await writer.grantConsent.estimateGas(...args);
      const gasLimit = (gas * 12n) / 10n;                 // 20% margin
      const sent = await writer.grantConsent(...args, { gasLimit });
      dispatch({ type: "signed", hash: sent.hash });
      const receipt = await sent.wait();
      dispatch({ type: "mined", block: receipt.blockNumber });
    } catch (err) {
      if (isError(err, "ACTION_REJECTED")) dispatch({ type: "user-rejected" });
      else {
        dispatch({ type: "reverted", reason: explainError(err, consentInterface) });
      }
    }
  }

  const busy = tx.status === "awaiting-signature" || tx.status === "pending";
  return (
    <section>
      <h2>Grant consent</h2>
      <input placeholder="Provider address 0x..." value={provider}
        onChange={(e) => setProvider(e.target.value.trim())} />
      <select value={category}
        onChange={(e) => setCategory(e.target.value as Category)}>
        {CATEGORIES.map((c) => <option key={c}>{c}</option>)}
      </select>
      <input type="number" min={1} max={365} value={days}
        onChange={(e) => setDays(Number(e.target.value))} /> days
      <input type="file" onChange={(e) => setDoc(e.target.files?.[0] ?? null)} />
      <button disabled={busy || !doc || !provider} onClick={submit}>Grant</button>
      <TxStatus tx={tx} onClose={() => dispatch({ type: "reset" })} />
    </section>
  );
}
