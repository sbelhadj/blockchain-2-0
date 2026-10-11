// One transaction flow for every write: simulate, send, track, explain errors.
import { useReducer } from "react";
import { isError, type ContractTransactionResponse } from "ethers";
import { explainError } from "../lib/errors";
import { txReducer } from "../lib/txMachine";
import { consentInterface } from "./useConsent";

export function useTx() {
  const [tx, dispatch] = useReducer(txReducer, { status: "idle" });

  async function run(
    label: string,
    simulate: () => Promise<unknown>,
    send: () => Promise<ContractTransactionResponse>,
  ) {
    dispatch({ type: "start", label });
    try {
      await simulate(); // reverts surface here
      const sent = await send();
      dispatch({ type: "signed", hash: sent.hash });
      const receipt = await sent.wait();
      dispatch({ type: "mined", block: receipt!.blockNumber });
    } catch (err) {
      if (isError(err, "ACTION_REJECTED")) dispatch({ type: "user-rejected" });
      else
        dispatch({ type: "reverted", reason: explainError(err, consentInterface) });
    }
  }

  return { tx, run, reset: () => dispatch({ type: "reset" }) };
}
