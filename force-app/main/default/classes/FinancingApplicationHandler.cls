/**
 * Logique du trigger FinancingApplicationTrigger.
 *
 * - Calcule la mensualité et le score de risque quand le montant, le taux ou la durée changent
 *   (ou quand la mensualité est vide, pour rattraper les anciens dossiers).
 * - Bloque la soumission d'un dossier dont le score dépasse Financing_Setting__mdt.Default.Max_Risk_Score__c.
 *
 * Bulkifié : aucune requête SOQL ni DML. Le Custom Metadata est lu via getInstance(),
 * qui ne consomme pas de requête SOQL.
 */
public with sharing class FinancingApplicationHandler {
    @TestVisible
    private static final String STATUS_SUBMITTED = 'Submitted';

    @TestVisible
    private static Decimal maxRiskScoreOverride;

    public static void handle(
        System.TriggerOperation operation,
        List<Financing_Application__c> newRecords,
        Map<Id, Financing_Application__c> oldMap
    ) {
        switch on operation {
            when BEFORE_INSERT, BEFORE_UPDATE {
                processBeforeSave(newRecords, oldMap);
            }
        }
    }

    private static void processBeforeSave(List<Financing_Application__c> newRecords, Map<Id, Financing_Application__c> oldMap) {
        Decimal maxRiskScore = getMaxRiskScore();
        for (Financing_Application__c application : newRecords) {
            Financing_Application__c previous = oldMap?.get(application.Id);
            if (needsRecalculation(application, previous)) {
                recalculate(application);
            }
            if (isBeingSubmitted(application, previous) && application.Risk_Score__c > maxRiskScore) {
                application.addError(
                    'Score de risque trop élevé (' + application.Risk_Score__c + ' > ' + maxRiskScore + ') : dossier non soumissible.'
                );
            }
        }
    }

    private static Boolean needsRecalculation(Financing_Application__c application, Financing_Application__c previous) {
        return previous == null ||
            application.Monthly_Payment__c == null ||
            application.Amount__c != previous.Amount__c ||
            application.Interest_Rate__c != previous.Interest_Rate__c ||
            application.Term_Months__c != previous.Term_Months__c;
    }

    private static void recalculate(Financing_Application__c application) {
        Integer termMonths = application.Term_Months__c?.intValue();
        // Les triggers "before" s'exécutent AVANT les règles de validation :
        // une durée invalide est laissée à la règle Term_Range, qui renverra le bon message.
        if (termMonths == null || termMonths <= 0) {
            return;
        }
        application.Monthly_Payment__c = LoanCalculator.monthlyPayment(application.Amount__c, application.Interest_Rate__c, termMonths);
        application.Risk_Score__c = RiskScoreCalculator.score(application.Amount__c, application.Interest_Rate__c, termMonths);
    }

    private static Boolean isBeingSubmitted(Financing_Application__c application, Financing_Application__c previous) {
        return application.Status__c == STATUS_SUBMITTED && (previous == null || previous.Status__c != STATUS_SUBMITTED);
    }

    private static Decimal getMaxRiskScore() {
        if (maxRiskScoreOverride != null) {
            return maxRiskScoreOverride;
        }
        Financing_Setting__mdt settings = Financing_Setting__mdt.getInstance('Default');
        return settings?.Max_Risk_Score__c ?? 100;
    }
}
