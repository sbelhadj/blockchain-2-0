import { WalletPicker } from "./components/WalletPicker";
import { ConsentForm } from "./components/ConsentForm";
import { ConsentList } from "./components/ConsentList";
import { useWallet } from "./hooks/useWallet";
import { useConsent } from "./hooks/useConsent";
import { ProviderPanel } from "./components/ProviderPanel";
import { HistoryPanel } from "./components/HistoryPanel";
import { ContractReader } from "./components/ContractReader";
import { CONSENT_ADDRESS } from "./config";
import { useEffect, useState } from "react";

export default function App() {
  const { signer, account, connect } = useWallet();
  const { reader, writer } = useConsent(signer);
  const [isProvider, setIsProvider] = useState(false);

  useEffect(() => {
    // role detection drives which view is shown
    if (!account) return;
    void (async () =>
      setIsProvider(await reader.hasRole(await reader.PROVIDER_ROLE(), account)))();
  }, [reader, account]);

  if (!CONSENT_ADDRESS) return <p>Set VITE_CONSENT_ADDRESS in .env.local.</p>;
  return (
    <main>
      <h1>Patient consent</h1>
      <ContractReader reader={reader} />
      {!account || !writer ? (
        <WalletPicker onPick={(w) => void connect(w)} />
      ) : (
        <>
          <p>Connected as {account}</p>
          {isProvider ? (
            <ProviderPanel reader={reader} writer={writer} account={account} />
          ) : (
            <>
              <ConsentForm writer={writer} />
              <ConsentList reader={reader} writer={writer} account={account} />
            </>
          )}
          <HistoryPanel reader={reader} account={account} />
        </>
      )}
    </main>
  );
}
