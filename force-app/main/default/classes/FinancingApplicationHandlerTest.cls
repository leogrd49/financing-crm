@IsTest
private class FinancingApplicationHandlerTest {
    @IsTest
    static void insertCalculatesPaymentAndScore() {
        Financing_Application__c application = TestDataFactory.buildApplications(1, 20000, 5, 48)[0];

        Test.startTest();
        insert application;
        Test.stopTest();

        application = [SELECT Monthly_Payment__c, Risk_Score__c FROM Financing_Application__c WHERE Id = :application.Id];
        Assert.areEqual(460.59, application.Monthly_Payment__c, 'Mensualité calculée à la création');
        Assert.areEqual(36, application.Risk_Score__c, 'Score calculé à la création');
    }

    @IsTest
    static void updateOfTermRecalculates() {
        Financing_Application__c application = TestDataFactory.buildApplications(1, 25000, 4.5, 48)[0];
        insert application;

        Test.startTest();
        application.Term_Months__c = 60;
        update application;
        Test.stopTest();

        application = [SELECT Monthly_Payment__c FROM Financing_Application__c WHERE Id = :application.Id];
        Assert.areEqual(466.08, application.Monthly_Payment__c, 'Mensualité recalculée après changement de durée');
    }

    @IsTest
    static void bulkInsertOf200RecordsAsFinancingUser() {
        User financingUser = TestDataFactory.createFinancingUser();
        List<Financing_Application__c> applications = TestDataFactory.buildApplications(200, 20000, 5, 48);

        Test.startTest();
        System.runAs(financingUser) {
            insert applications;
        }
        Integer queriesUsed = Limits.getQueries();
        Test.stopTest();

        Assert.areEqual(0, queriesUsed, 'Le trigger ne doit consommer aucune requête SOQL');
        List<Financing_Application__c> saved = [
            SELECT Monthly_Payment__c
            FROM Financing_Application__c
            WHERE Id IN :applications
        ];
        Assert.areEqual(200, saved.size());
        for (Financing_Application__c application : saved) {
            Assert.areEqual(460.59, application.Monthly_Payment__c, 'Chaque dossier du lot est calculé');
        }
    }

    @IsTest
    static void submissionBlockedWhenRiskTooHigh() {
        FinancingApplicationHandler.maxRiskScoreOverride = 10;
        Financing_Application__c application = TestDataFactory.buildApplications(1, 20000, 5, 48)[0];
        insert application;

        application.Status__c = FinancingApplicationHandler.STATUS_SUBMITTED;
        Test.startTest();
        Database.SaveResult result = Database.update(application, false);
        Test.stopTest();

        Assert.isFalse(result.isSuccess(), 'Un dossier trop risqué ne doit pas pouvoir être soumis');
        Assert.isTrue(result.getErrors()[0].getMessage().contains('Score de risque trop élevé'), result.getErrors()[0].getMessage());
    }

    @IsTest
    static void submissionAllowedWhenRiskAcceptable() {
        FinancingApplicationHandler.maxRiskScoreOverride = 50;
        Financing_Application__c application = TestDataFactory.buildApplications(1, 20000, 5, 48)[0];
        insert application;

        application.Status__c = FinancingApplicationHandler.STATUS_SUBMITTED;
        Test.startTest();
        Database.SaveResult result = Database.update(application, false);
        Test.stopTest();

        Assert.isTrue(result.isSuccess(), 'Score 36 <= 50 : la soumission passe');
    }

    @IsTest
    static void invalidTermIsLeftToValidationRule() {
        Financing_Application__c application = TestDataFactory.buildApplications(1, 20000, 5, 0)[0];

        Test.startTest();
        Database.SaveResult result = Database.insert(application, false);
        Test.stopTest();

        Assert.isFalse(result.isSuccess());
        Assert.isTrue(result.getErrors()[0].getMessage().contains('12 et 96'), 'Message de la règle Term_Range, pas une exception Apex');
    }
}
