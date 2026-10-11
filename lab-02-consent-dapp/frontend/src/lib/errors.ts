// Turn ethers v6 errors into messages a user can act on.
import { Interface, isError } from "ethers";

export function explainError(err: unknown, iface: Interface): string {
  if (isError(err, "ACTION_REJECTED")) return "You rejected the request.";
  if (isError(err, "INSUFFICIENT_FUNDS")) return "Not enough ETH to pay for gas.";
  if (isError(err, "CALL_EXCEPTION")) {
    const data = err.data ?? (err as { info?: { error?: { data?: string } } })
      .info?.error?.data;
    if (data) {
      const parsed = iface.parseError(data);   // custom error from our contract?
      if (parsed) return `${parsed.name}(${parsed.args.join(", ")})`;
    }
    return err.reason ?? "The transaction would revert.";
  }
  if (isError(err, "NETWORK_ERROR")) return "Network problem, please retry.";
  return (err as Error).message ?? String(err);
}
