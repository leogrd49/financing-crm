"use server";

import { createApplication, type Application, type ApplicationPayload } from "@/lib/salesforce";

/** Valeurs saisies, renvoyées au formulaire pour qu'il ne se vide pas après l'envoi */
export type FormValues = Record<string, string>;

export type FormState =
  | { status: "idle"; values?: FormValues }
  | { status: "success"; application: Application; values: FormValues }
  | { status: "error"; errors: string[]; values: FormValues };

const FIELDS = ["amount", "termMonths", "vin", "firstName", "lastName", "email", "phone", "submit"];

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
  if (!VIN_PATTERN.test(payload.vin)) errors.push("VIN invalide : 17 caractères, sans I, O ni Q.");
  if (!payload.borrower.lastName) errors.push("Le nom est obligatoire.");
  if (!payload.borrower.email.includes("@")) errors.push("L'email est invalide.");

  return errors.length ? { errors } : { payload, errors };
}

export async function submitApplication(_previous: FormState, formData: FormData): Promise<FormState> {
  const values: FormValues = Object.fromEntries(FIELDS.map((field) => [field, text(formData, field)]));
  const { payload, errors } = parse(formData);
  if (!payload) {
    return { status: "error", errors, values };
  }

  try {
    const result = await createApplication(payload);
    return result.ok
      ? { status: "success", application: result.application, values }
      : { status: "error", errors: result.errors, values };
  } catch (error) {
    // Le détail technique reste dans les logs serveur, jamais renvoyé au navigateur
    console.error(error);
    return { status: "error", errors: ["Le service est momentanément indisponible. Réessayez plus tard."], values };
  }
}
