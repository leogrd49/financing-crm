@IsTest
private class LoanSimulatorControllerTest {
  @IsTest
  static void applyTermsRecalculatesOnServer() {
    Financing_Application__c application = TestDataFactory.buildApplications(
      1,
      25000,
      4.5,
      48
    )[0];
    insert application;

    Test.startTest();
    Financing_Application__c updated = LoanSimulatorController.applyTerms(
      application.Id,
      60,
      4.5
    );
    Test.stopTest();

    Assert.areEqual(
      466.08,
      updated.Monthly_Payment__c,
      'Mensualité recalculée par le trigger'
    );
  }

  @IsTest
  static void refusesNonDraftApplication() {
    Financing_Application__c application = TestDataFactory.buildApplications(
      1,
      20000,
      5,
      48
    )[0];
    application.Status__c = 'Submitted';
    insert application;

    try {
      LoanSimulatorController.applyTerms(application.Id, 60, 4);
      Assert.fail(
        'Un dossier soumis ne doit pas être modifiable depuis le simulateur'
      );
    } catch (AuraHandledException e) {
      Assert.isTrue(e.getMessage().contains('brouillon'), e.getMessage());
    }
  }

  @IsTest
  static void returnsValidationRuleMessage() {
    Financing_Application__c application = TestDataFactory.buildApplications(
      1,
      20000,
      5,
      48
    )[0];
    insert application;

    try {
      LoanSimulatorController.applyTerms(application.Id, 120, 5);
      Assert.fail('Une durée de 120 mois doit être refusée');
    } catch (AuraHandledException e) {
      Assert.isTrue(e.getMessage().contains('12 et 96'), e.getMessage());
    }
  }

  @IsTest
  static void unknownApplication() {
    Financing_Application__c application = TestDataFactory.buildApplications(
      1,
      20000,
      5,
      48
    )[0];
    insert application;
    Id deletedId = application.Id;
    delete application;

    try {
      LoanSimulatorController.applyTerms(deletedId, 48, 5);
      Assert.fail('Un dossier inexistant doit lever une erreur');
    } catch (AuraHandledException e) {
      Assert.isTrue(e.getMessage().contains('introuvable'), e.getMessage());
    }
  }
}
