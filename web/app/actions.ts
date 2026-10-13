"use server";

import { createApplication, type Application, type ApplicationPayload } from "@/lib/salesforce";

export type FormState =
  | { status: "idle" }
  | { status: "success"; application: Application }
  | { status: "error"; errors: string[] };

const VIN_PATTERN = /^[A-HJ-NPR-Z0-9]{17}$/;

function text(formData: FormData, field: string): string {
  return String(formData.get(field) ?? "").trim();
}

function toNumber(value: string): number {
  return value === "" ? Number.NaN : Number(value.replace(",", "."));
}

/** Validation rapide côté serveur ; Salesforce reste la source de vérité (règles de validation). */
function parse(formData: FormData): { payload?: ApplicationPayload; errors: string[] } {
  const payload: ApplicationPayload = {
    amount: toNumber(text(formData, "amount")),
    termMonths: toNumber(text(formData, "termMonths")),
    interestRate: toNumber(text(formData, "interestRate")),
    vin: text(formData, "vin").toUpperCase(),
    submit: formData.get("submit") === "on",
    borrower: {
      firstName: text(formData, "firstName"),
      lastName: text(formData, "lastName"),
      email: text(formData, "email"),
      phone: text(formData, "phone"),
    },
  };

  const errors: string[] = [];
  if (!(payload.amount > 0)) errors.push("Le montant doit être un nombre positif.");
  if (!Number.isInteger(payload.termMonths)) errors.push("La durée doit être un nombre entier de mois.");
  if (!(payload.interestRate >= 0)) errors.push("Le taux doit être un nombre positif ou nul.");
  if (!VIN_PATTERN.test(payload.vin)) errors.push("VIN invalide : 17 caractères, sans I, O ni Q.");
  if (!payload.borrower.lastName) errors.push("Le nom est obligatoire.");
  if (!payload.borrower.email.includes("@")) errors.push("L'email est invalide.");

  return errors.length ? { errors } : { payload, errors };
}

export async function submitApplication(_previous: FormState, formData: FormData): Promise<FormState> {
  const { payload, errors } = parse(formData);
  if (!payload) {
    return { status: "error", errors };
  }

  try {
    const result = await createApplication(payload);
    return result.ok
      ? { status: "success", application: result.application }
      : { status: "error", errors: result.errors };
  } catch (error) {
    // Le détail technique reste dans les logs serveur, jamais renvoyé au navigateur
    console.error(error);
    return { status: "error", errors: ["Le service est momentanément indisponible. Réessayez plus tard."] };
  }
}
