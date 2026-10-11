// Lab 2, Part D step 4: what a provider sees. Check consent, then record access.
import { useState } from "react";
import { id, isAddress, type Contract } from "ethers";
import { CATEGORIES, categoryCode, type Category } from "../lib/codes";
import { useTx } from "../hooks/useTx";
import { TxStatus } from "./TxStatus";

export function ProviderPanel({
  reader,
  writer,
  account,
}: {
  reader: Contract;
  writer: Contract;
  account: string;
}) {
  const [patient, setPatient] = useState("");
  const [category, setCategory] = useState<Category>("LAB_RESULTS");
  const [active, setActive] = useState<boolean | null>(null);
  const { tx, run, reset } = useTx();

  async function check() {
    setActive(
      await reader.hasActiveConsent(patient, account, categoryCode(category)),
    );
  }
  const args = () => [patient, categoryCode(category), id("READ")] as const;

  return (
    <section>
      <h2>Provider: check and record access</h2>
      <input
        placeholder="Patient address 0x..."
        value={patient}
        onChange={(e) => {
          setPatient(e.target.value.trim());
          setActive(null);
        }}
      />
      <select
        value={category}
        onChange={(e) => {
          setCategory(e.target.value as Category);
          setActive(null);
        }}
      >
        {CATEGORIES.map((c) => (
          <option key={c}>{c}</option>
        ))}
      </select>
      <button disabled={!isAddress(patient)} onClick={() => void check()}>
        Check
      </button>
      {active !== null && <p>Active consent: {active ? "yes" : "no"}</p>}
      <button
        disabled={!isAddress(patient)}
        onClick={() =>
          run(
            "Record access",
            () => writer.recordAccess.estimateGas(...args()),
            () => writer.recordAccess(...args()),
          )
        }
      >
        Record access
      </button>
      <TxStatus tx={tx} onClose={reset} />
    </section>
  );
}
