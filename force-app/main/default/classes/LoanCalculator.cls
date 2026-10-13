/**
 * Calcul de la mensualité d'un prêt amortissable (mensualités constantes).
 *
 * ✍️ EXERCICE : à écrire toi-même, sans IA.
 *    Les tests sont déjà écrits dans LoanCalculatorTest : ils doivent tous passer au vert.
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
    /**
     * @param amount            capital emprunté
     * @param annualRatePercent taux annuel en pourcentage (4.5 pour 4,5 %)
     * @param termMonths        durée en mois
     * @return mensualité arrondie au centime
     */
    public static Decimal monthlyPayment(Decimal amount, Decimal annualRatePercent, Integer termMonths) {
        // TODO : à toi de jouer
        return null;
    }
}
