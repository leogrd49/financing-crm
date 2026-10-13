import "server-only";

/**
 * Client Salesforce côté serveur (OAuth 2.0 Client Credentials).
 *
 * Le secret ne quitte jamais le serveur : `server-only` fait échouer le build
 * si ce module est importé par erreur dans un composant client.
 */

export type ApplicationPayload = {
  amount: number;
  termMonths: number;
  vin: string;
  submit: boolean;
  borrower: {
    firstName: string;
    lastName: string;
    email: string;
    phone: string;
  };
};

export type Application = {
  id: string;
  name: string;
  status: string;
  amount: number;
  termMonths: number;
  interestRate: number;
  monthlyPayment: number | null;
  riskScore: number | null;
  vin: string;
};

export type ApiResult =
  | { ok: true; application: Application }
  | { ok: false; errors: string[] };

type Token = { accessToken: string; instanceUrl: string; expiresAt: number };

// Salesforce ne renvoie pas de durée de validité en Client Credentials :
// on garde le jeton 30 min et on le renouvelle sur un 401.
const TOKEN_TTL_MS = 30 * 60 * 1000;
const API_PATH = "/services/apexrest/financing-applications";

let cachedToken: Token | null = null;

function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Variable d'environnement manquante : ${name} (voir .env.example)`);
  }
  return value;
}

async function getToken(forceRefresh = false): Promise<Token> {
  if (!forceRefresh && cachedToken && cachedToken.expiresAt > Date.now()) {
    return cachedToken;
  }

  const response = await fetch(`${requireEnv("SF_DOMAIN_URL")}/services/oauth2/token`, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "client_credentials",
      client_id: requireEnv("SF_CLIENT_ID"),
      client_secret: requireEnv("SF_CLIENT_SECRET"),
    }),
    cache: "no-store",
  });

  if (!response.ok) {
    const detail = await response.text();
    throw new Error(`Authentification Salesforce refusée (${response.status}) : ${detail}`);
  }

  const body = (await response.json()) as { access_token: string; instance_url: string };
  cachedToken = {
    accessToken: body.access_token,
    instanceUrl: body.instance_url,
    expiresAt: Date.now() + TOKEN_TTL_MS,
  };
  return cachedToken;
}

async function callApi(payload: ApplicationPayload, forceRefresh: boolean): Promise<Response> {
  const token = await getToken(forceRefresh);
  return fetch(`${token.instanceUrl}${API_PATH}`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token.accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(payload),
    cache: "no-store",
  });
}

export async function createApplication(payload: ApplicationPayload): Promise<ApiResult> {
  let response = await callApi(payload, false);
  if (response.status === 401) {
    response = await callApi(payload, true);
  }

  const body = await response.json();
  if (response.status === 201) {
    return { ok: true, application: body as Application };
  }
  if (response.status === 400 && Array.isArray(body?.errors)) {
    return { ok: false, errors: body.errors };
  }
  throw new Error(`Réponse inattendue de Salesforce (${response.status}) : ${JSON.stringify(body)}`);
}
