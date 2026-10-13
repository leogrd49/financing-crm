/**
 * Score de risque d'un dossier, de 0 (faible) à 100 (maximal).
 *
 * Modèle volontairement simple (le projet n'a pas de données de revenus) :
 *    - Montant : jusqu'à 40 points (plafond atteint à 100 000 €)
 *    - Durée   : jusqu'à 30 points (12 mois = 0, 96 mois = 30)
 *    - Taux    : jusqu'à 30 points (10 % et plus = 30)
 */
public with sharing class RiskScoreCalculator {
    private static final Decimal AMOUNT_MAX_POINTS = 40;
    private static final Decimal AMOUNT_PER_POINT = 2500;
    private static final Decimal TERM_MAX_POINTS = 30;
    private static final Integer TERM_MIN_MONTHS = 12;
    private static final Integer TERM_RANGE_MONTHS = 84;
    private static final Decimal RATE_MAX_POINTS = 30;
    private static final Decimal POINTS_PER_RATE_PERCENT = 3;

    public static Integer score(Decimal amount, Decimal annualRatePercent, Integer termMonths) {
        if (amount == null || annualRatePercent == null || termMonths == null) {
            return null;
        }
        Decimal amountPoints = clamp(amount / AMOUNT_PER_POINT, AMOUNT_MAX_POINTS);
        Decimal termPoints = clamp((termMonths - TERM_MIN_MONTHS) * TERM_MAX_POINTS / TERM_RANGE_MONTHS, TERM_MAX_POINTS);
        Decimal ratePoints = clamp(annualRatePercent * POINTS_PER_RATE_PERCENT, RATE_MAX_POINTS);
        return (amountPoints + termPoints + ratePoints).round(System.RoundingMode.HALF_UP).intValue();
    }

    private static Decimal clamp(Decimal value, Decimal max) {
        return Math.max(0, Math.min(value, max));
    }
}
