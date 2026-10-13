/**
 * Même formule que la classe Apex LoanCalculator, pour un aperçu instantané sans appel serveur.
 * La valeur enregistrée reste celle calculée par l'Apex.
 */
export function monthlyPayment(amount, annualRatePercent, termMonths) {
  if (
    amount == null ||
    annualRatePercent == null ||
    termMonths == null ||
    termMonths <= 0
  ) {
    return null;
  }
  const monthlyRate = annualRatePercent / 100 / 12;
  const payment =
    monthlyRate === 0
      ? amount / termMonths
      : (amount * monthlyRate) / (1 - Math.pow(1 + monthlyRate, -termMonths));
  return roundToCents(payment);
}

export function totalInterest(amount, payment, termMonths) {
  if (amount == null || payment == null || termMonths == null) {
    return null;
  }
  return roundToCents(payment * termMonths - amount);
}

function roundToCents(value) {
  return Math.round((value + Number.EPSILON) * 100) / 100;
}
