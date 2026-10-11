// The patient's consents, rebuilt from events and checked against current state.
import { useCallback, useEffect, useState } from "react";
import type { Contract, EventLog } from "ethers";
import { DEPLOY_BLOCK } from "../config";
import { queryPaged } from "../lib/events";
import { categoryLabel } from "../lib/codes";
import { RevokeButton } from "./RevokeButton";

interface Row {
  id: bigint; provider: string; category: string;
  expiresAt: bigint; active: boolean;
}

export function ConsentList({ reader, writer, account }:
  { reader: Contract; writer: Contract; account: string }) {
  const [rows, setRows] = useState<Row[]>([]);

  const load = useCallback(async () => {
    const latest = await reader.runner!.provider!.getBlockNumber();
    const filter = reader.filters.ConsentGranted(null, account); // indexed patient
    const logs = await queryPaged(reader, filter, DEPLOY_BLOCK, latest);
    const list = await Promise.all((logs as EventLog[]).map(async (log) => {
      const id = log.args.consentId as bigint;
      // Events say what happened; the current state says what is true now.
      const current = await reader.consents(id);
      return { id, provider: log.args.provider, category: log.args.category,
        expiresAt: current.expiresAt, active: current.active };
    }));
    setRows(list.reverse());
  }, [reader, account]);

  useEffect(() => {
    void load();
    // Live updates: refresh whenever this patient grants or revokes.
    const granted = reader.filters.ConsentGranted(null, account);
    const revoked = reader.filters.ConsentRevoked(null, account);
    void reader.on(granted, load);
    void reader.on(revoked, load);
    return () => {
      void reader.off(granted, load);
      void reader.off(revoked, load);
    };
  }, [reader, account, load]);

  return (
    <section>
      <h2>My consents</h2>
      <table><tbody>
        {rows.map((r) => (
          <tr key={r.id.toString()}>
            <td>#{r.id.toString()}</td><td>{r.provider}</td>
            <td>{categoryLabel(r.category)}</td>
            <td>{new Date(Number(r.expiresAt) * 1000).toLocaleDateString()}</td>
            <td>{r.active
              ? <RevokeButton writer={writer} id={r.id} />
              : "inactive"}</td>
          </tr>
        ))}
      </tbody></table>
    </section>
  );
}
