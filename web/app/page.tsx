import { ApplicationForm } from "./application-form";
import styles from "./page.module.css";

export default function Home() {
  return (
    <main className={styles.main}>
      <header className={styles.header}>
        <h1>Demande de financement auto</h1>
        <p>Votre dossier est créé directement dans notre CRM Salesforce. Le véhicule est identifié à partir de son VIN.</p>
      </header>
      <ApplicationForm />
    </main>
  );
}
