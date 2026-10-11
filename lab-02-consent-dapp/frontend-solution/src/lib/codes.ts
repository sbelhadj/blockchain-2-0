// Published category list. The chain stores keccak256 of a label, never free text.
import { id, keccak256 } from "ethers";

export const CATEGORIES =
  ["LAB_RESULTS", "IMAGING", "PRESCRIPTIONS", "VACCINATIONS"] as const;
export type Category = (typeof CATEGORIES)[number];

export const categoryCode = (c: Category) => id(c);
export const categoryLabel = (code: string) =>
  CATEGORIES.find((c) => id(c) === code) ?? "unknown category";

/** The purpose document stays off-chain; only its hash is written. */
export const purposeHash = (documentBytes: Uint8Array) => keccak256(documentBytes);
