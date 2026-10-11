// Contract objects: one read-only (public RPC), one that signs (the wallet).
import { useMemo } from "react";
import { Contract, Interface, JsonRpcProvider, type JsonRpcSigner } from "ethers";
import abi from "../abi/PatientConsent.json";
import { CONSENT_ADDRESS, RPC_URL } from "../config";

export const consentInterface = new Interface(abi);
const readProvider = new JsonRpcProvider(RPC_URL);

export function useConsent(signer: JsonRpcSigner | null) {
  return useMemo(() => ({
    reader: new Contract(CONSENT_ADDRESS, consentInterface, readProvider),
    writer: signer ? new Contract(CONSENT_ADDRESS, consentInterface, signer) : null,
  }), [signer]);
}
