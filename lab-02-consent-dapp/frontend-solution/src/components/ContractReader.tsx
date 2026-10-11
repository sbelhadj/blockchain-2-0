// Exercise 4.2 solution: read one consent by id, no wallet, refreshed every block.
import { useEffect, useState } from "react";
import type { Contract } from "ethers";
import { categoryLabel } from "../lib/codes";

export function ContractReader({ reader }: { reader: Contract }) {
  const [id, setId] = useState("1");
  const [row, setRow] = useState<string>("");

  useEffect(() => {
    const provider = reader.runner!.provider!;
    const refresh = async () => {
      const c = await reader.consents(BigInt(id || "0"));
      setRow(
        c.patient === "0x0000000000000000000000000000000000000000"
          ? "no such consent"
          : `${c.patient} to ${c.provider}, ${categoryLabel(c.category)}, ` +
              `until ${new Date(Number(c.expiresAt) * 1000).toISOString()}, ` +
              `${c.active ? "active" : "inactive"}`,
      );
    };
    void refresh();
    void provider.on("block", refresh); // re-read on every new block
    return () => {
      void provider.off("block", refresh);
    };
  }, [reader, id]);

  return (
    <section>
      <h2>Consent reader</h2>
      <input
        value={id}
        onChange={(e) => setId(e.target.value.replace(/\D/g, ""))}
      />
      <p>{row}</p>
    </section>
  );
}
