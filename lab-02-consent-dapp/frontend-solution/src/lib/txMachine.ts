// Every state a user-initiated transaction can be in, and the allowed moves.
export type TxState =
  | { status: "idle" }
  | { status: "awaiting-signature"; label: string }
  | { status: "pending"; label: string; hash: string }
  | { status: "confirmed"; label: string; hash: string; block: number }
  | { status: "failed"; label: string; reason: string; hash?: string }
  | { status: "rejected"; label: string };

export type TxEvent =
  | { type: "start"; label: string }
  | { type: "signed"; hash: string }
  | { type: "mined"; block: number }
  | { type: "reverted"; reason: string }
  | { type: "user-rejected" }
  | { type: "reset" };

export function txReducer(state: TxState, event: TxEvent): TxState {
  switch (event.type) {
    case "start":
      return state.status === "awaiting-signature" || state.status === "pending"
        ? state                                  // one transaction at a time
        : { status: "awaiting-signature", label: event.label };
    case "signed":
      return state.status === "awaiting-signature"
        ? { status: "pending", label: state.label, hash: event.hash } : state;
    case "mined":
      return state.status === "pending"
        ? { status: "confirmed", label: state.label, hash: state.hash,
            block: event.block }
        : state;
    case "reverted":
      return state.status === "awaiting-signature" || state.status === "pending"
        ? { status: "failed", label: state.label, reason: event.reason,
            hash: state.status === "pending" ? state.hash : undefined }
        : state;
    case "user-rejected":
      return state.status === "awaiting-signature"
        ? { status: "rejected", label: state.label } : state;
    case "reset":
      return { status: "idle" };
  }
}
