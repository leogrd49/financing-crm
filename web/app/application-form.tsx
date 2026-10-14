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
const percent = new Intl.NumberFormat("fr-FR", { style: "percent", maximumFractionDigits: 2 });

export function ApplicationForm() {
  const [state, formAction, pending] = useActionState(submitApplication, initialState);
  // React vide le formulaire après l'envoi : on le recharge avec les valeurs saisies
  const values = state.values ?? {};

  return (
    <form action={formAction} className={styles.form}>
      <fieldset className={styles.fieldset}>
        <legend>Votre financement</legend>
        <label>
          Montant (€)
          <input name="amount" type="number" min="1" step="0.01" defaultValue={values.amount ?? "25000"} required />
        </label>
        <label>
          Durée (mois)
          <input name="termMonths" type="number" min="12" max="96" step="1" defaultValue={values.termMonths ?? "48"} required />
        </label>
        <label className={styles.wide}>
          VIN du véhicule
          <input name="vin" defaultValue={values.vin} maxLength={17} placeholder="JN1AZ4EH7DM430111" required className={styles.mono} />
        </label>
      </fieldset>

      <fieldset className={styles.fieldset}>
        <legend>Vos coordonnées</legend>
        <label>
          Prénom
          <input name="firstName" defaultValue={values.firstName} autoComplete="given-name" />
        </label>
        <label>
          Nom
          <input name="lastName" defaultValue={values.lastName} autoComplete="family-name" required />
        </label>
        <label>
          Email
          <input name="email" type="email" defaultValue={values.email} autoComplete="email" required />
        </label>
        <label>
          Téléphone
          <input name="phone" type="tel" defaultValue={values.phone} autoComplete="tel" />
        </label>
      </fieldset>

      <label className={styles.checkbox}>
        <input name="submit" type="checkbox" defaultChecked={values.submit === undefined || values.submit === "on"} />
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
              <dd>{percent.format(state.application.interestRate / 100)}</dd>
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
