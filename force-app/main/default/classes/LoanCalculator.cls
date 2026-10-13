/**
 * Calcul de la mensualité d'un prêt amortissable (mensualités constantes).
 *
 * ✍️ EXERCICE À REFAIRE SEUL : effacer le corps de monthlyPayment et le réécrire
 *    jusqu'à ce que LoanCalculatorTest repasse au vert.
 *
 * Formule :  M = P * r / (1 - (1 + r)^-n)
 *    P = capital emprunté
 *    r = taux MENSUEL en décimal  (ex. 4,5 % par an -> 4.5 / 100 / 12)
 *    n = nombre de mensualités
 *
 * Règles :
 *    - un paramètre null                -> retourner null
 *    - termMonths <= 0                  -> lever une IllegalArgumentException
 *    - taux à 0                         -> M = P / n  (sinon division par zéro !)
 *    - résultat arrondi au centime      -> setScale(2, System.RoundingMode.HALF_UP)
 *
 * Indices Apex :
 *    - Decimal.pow(Integer) existe, mais pas avec un exposant négatif : x^-n = 1 / x^n
 *    - attention à la précision : garde les calculs en Decimal jusqu'à l'arrondi final
 */
public with sharing class LoanCalculator {
    private static final Integer MONTHS_PER_YEAR = 12;
    // Précision des calculs intermédiaires : on n'arrondit qu'à la toute fin
    private static final Integer CALCULATION_SCALE = 18;

    /**
     * @param amount            capital emprunté
     * @param annualRatePercent taux annuel en pourcentage (4.5 pour 4,5 %)
     * @param termMonths        durée en mois
     * @return mensualité arrondie au centime
     */
    public static Decimal monthlyPayment(Decimal amount, Decimal annualRatePercent, Integer termMonths) {
        if (amount == null || annualRatePercent == null || termMonths == null) {
            return null;
        }
        if (termMonths <= 0) {
            throw new IllegalArgumentException('La durée doit être strictement positive (reçu : ' + termMonths + ').');
        }

        Decimal monthlyRate = annualRatePercent.divide(MONTHS_PER_YEAR * 100, CALCULATION_SCALE);
        if (monthlyRate == 0) {
            return amount.divide(termMonths, 2, System.RoundingMode.HALF_UP);
        }

        // (1 + r)^-n = 1 / (1 + r)^n, car Decimal.pow() n'accepte pas d'exposant négatif
        Decimal growthFactor = (1 + monthlyRate).pow(termMonths);
        Decimal payment = amount * monthlyRate / (1 - 1 / growthFactor);
        return payment.setScale(2, System.RoundingMode.HALF_UP);
    }
}
