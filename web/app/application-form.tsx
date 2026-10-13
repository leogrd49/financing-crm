"use client";

import { useActionState } from "react";
import { submitApplication, type FormState } from "./actions";
import styles from "./page.module.css";

const initialState: FormState = { status: "idle" };

const STATUS_LABELS: Record<string, string> = {
  Draft: "Brouillon",
  Submitted: "Soumis",
  In_Approval: "En approbation",
  Approved: "Approuvé",
  Rejected: "Refusé",
};

const euros = new Intl.NumberFormat("fr-FR", { style: "currency", currency: "EUR" });

export function ApplicationForm() {
  const [state, formAction, pending] = useActionState(submitApplication, initialState);

  return (
    <form action={formAction} className={styles.form}>
      <fieldset className={styles.fieldset}>
        <legend>Votre financement</legend>
        <label>
          Montant (€)
          <input name="amount" type="number" min="1" step="0.01" defaultValue="25000" required />
        </label>
        <label>
          Durée (mois)
          <input name="termMonths" type="number" min="12" max="96" step="1" defaultValue="48" required />
        </label>
        <label className={styles.wide}>
          VIN du véhicule
          <input name="vin" maxLength={17} placeholder="JN1AZ4EH7DM430111" required className={styles.mono} />
        </label>
      </fieldset>

      <fieldset className={styles.fieldset}>
        <legend>Vos coordonnées</legend>
        <label>
          Prénom
          <input name="firstName" autoComplete="given-name" />
        </label>
        <label>
          Nom
          <input name="lastName" autoComplete="family-name" required />
        </label>
        <label>
          Email
          <input name="email" type="email" autoComplete="email" required />
        </label>
        <label>
          Téléphone
          <input name="phone" type="tel" autoComplete="tel" />
        </label>
      </fieldset>

      <label className={styles.checkbox}>
        <input name="submit" type="checkbox" defaultChecked />
        Soumettre directement le dossier pour étude
      </label>

      <button type="submit" disabled={pending} className={styles.button}>
        {pending ? "Envoi en cours…" : "Envoyer ma demande"}
      </button>

      <div aria-live="polite">
        {state.status === "error" && (
          <ul className={styles.errors}>
            {state.errors.map((error) => (
              <li key={error}>{error}</li>
            ))}
          </ul>
        )}
        {state.status === "success" && (
          <div className={styles.success}>
            <p>
              Dossier <strong>{state.application.name}</strong> créé — statut :{" "}
              <strong>{STATUS_LABELS[state.application.status] ?? state.application.status}</strong>
            </p>
            <dl>
              <dt>Taux appliqué</dt>
              <dd>{state.application.interestRate} %</dd>
              <dt>Mensualité</dt>
              <dd>{state.application.monthlyPayment == null ? "—" : euros.format(state.application.monthlyPayment)}</dd>
              <dt>Score de risque</dt>
              <dd>{state.application.riskScore ?? "—"} / 100</dd>
            </dl>
          </div>
        )}
      </div>
    </form>
  );
}
