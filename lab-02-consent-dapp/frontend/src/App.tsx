import { WalletPicker } from "./components/WalletPicker";
import { ConsentForm } from "./components/ConsentForm";
import { ConsentList } from "./components/ConsentList";
import { useWallet } from "./hooks/useWallet";
import { useConsent } from "./hooks/useConsent";
import { CONSENT_ADDRESS } from "./config";

export default function App() {
  const { signer, account, connect } = useWallet();
  const { reader, writer } = useConsent(signer);

  if (!CONSENT_ADDRESS) return <p>Set VITE_CONSENT_ADDRESS in .env.local.</p>;
  return (
    <main>
      <h1>Patient consent</h1>
      {!account || !writer ? <WalletPicker onPick={(w) => void connect(w)} /> : (
        <>
          <p>Connected as {account}</p>
          <ConsentForm writer={writer} />
          <ConsentList reader={reader} writer={writer} account={account} />
        </>
      )}
    </main>
  );
}
