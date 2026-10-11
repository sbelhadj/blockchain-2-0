// Lab 2, Part D step 5 (Exercise 4.3): every consent event involving this account.
import { useEffect, useState } from "react";
import type { Contract, EventLog } from "ethers";
import { DEPLOY_BLOCK } from "../config";
import { queryPaged } from "../lib/events";
import { categoryLabel } from "../lib/codes";

interface Item {
  key: string;
  block: number;
  text: string;
}

export function HistoryPanel({
  reader,
  account,
}: {
  reader: Contract;
  account: string;
}) {
  const [items, setItems] = useState<Item[]>([]);

  useEffect(() => {
    let cancelled = false;
    async function load() {
      const latest = await reader.runner!.provider!.getBlockNumber();
      const f = reader.filters;
      const filters = [
        f.ConsentGranted(null, account),
        f.ConsentGranted(null, null, account),
        f.ConsentRevoked(null, account),
        f.ConsentRevoked(null, null, account),
        f.DataAccessed(account),
        f.DataAccessed(null, account),
      ];
      const pages = await Promise.all(
        filters.map((flt) => queryPaged(reader, flt, DEPLOY_BLOCK, latest)),
      );
      const seen = new Map<string, Item>(); // a log can match twice
      for (const log of pages.flat() as EventLog[]) {
        const key = `${log.transactionHash}:${log.index}`;
        const a = log.args;
        const text =
          log.eventName === "DataAccessed"
            ? `access to ${categoryLabel(a.category)} by ${a.provider}`
            : `${log.eventName} #${a.consentId} (${a.patient} to ${a.provider})`;
        seen.set(key, { key, block: log.blockNumber, text });
      }
      if (!cancelled)
        setItems([...seen.values()].sort((x, y) => y.block - x.block));
    }
    void load();
    return () => {
      cancelled = true;
    };
  }, [reader, account]);

  return (
    <section>
      <h2>History</h2>
      <ul>
        {items.map((i) => (
          <li key={i.key}>
            block {i.block}: {i.text}
          </li>
        ))}
      </ul>
    </section>
  );
}
