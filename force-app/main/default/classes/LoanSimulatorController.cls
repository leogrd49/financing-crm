/**
 * Contrôleur du composant LWC loanSimulator : applique la durée et le taux simulés à un dossier.
 *
 * La mensualité n'est PAS envoyée par le navigateur : le trigger la recalcule côté serveur
 * (le simulateur n'est qu'un aperçu, l'Apex reste la source de vérité).
 */
public with sharing class LoanSimulatorController {
  @TestVisible
  private static final String STATUS_DRAFT = 'Draft';

  @AuraEnabled
  public static Financing_Application__c applyTerms(
    Id applicationId,
    Integer termMonths,
    Decimal interestRate
  ) {
    List<Financing_Application__c> found = [
      SELECT Id, Status__c
      FROM Financing_Application__c
      WHERE Id = :applicationId
      WITH USER_MODE
    ];
    if (found.isEmpty()) {
      throw auraError('Dossier introuvable.');
    }
    if (found[0].Status__c != STATUS_DRAFT) {
      throw auraError('Seul un dossier en brouillon peut être modifié.');
    }

    Financing_Application__c application = new Financing_Application__c(
      Id = applicationId,
      Term_Months__c = termMonths,
      Interest_Rate__c = interestRate
    );
    try {
      update as user application;
    } catch (DmlException e) {
      throw auraError(e.getDmlMessage(0));
    }

    return [
      SELECT Id, Monthly_Payment__c, Risk_Score__c
      FROM Financing_Application__c
      WHERE Id = :applicationId
      WITH USER_MODE
    ];
  }

  // setMessage() : sans lui, getMessage() renvoie "Script-thrown exception" dans les tests
  private static AuraHandledException auraError(String message) {
    AuraHandledException error = new AuraHandledException(message);
    error.setMessage(message);
    return error;
  }
}
