@IsTest
private class FinancingApplicationApiTest {
    private static final String VALID_BODY = JSON.serialize(
        new Map<String, Object>{
            'amount' => 20000,
            'termMonths' => 48,
            // Tentative d'imposer un taux à 0 % : doit être ignorée
            'interestRate' => 0,
            'vin' => NhtsaHttpMock.HONDA_VIN,
            'borrower' => new Map<String, Object>{ 'firstName' => 'Marie', 'lastName' => 'Martin', 'email' => 'Marie.Martin@example.com' }
        }
    );

    private static void mockRequest(String method, String uri, String body) {
        RestRequest request = new RestRequest();
        request.httpMethod = method;
        request.requestURI = uri;
        request.requestBody = body == null ? null : Blob.valueOf(body);
        RestContext.request = request;
        RestContext.response = new RestResponse();
    }

    private static Map<String, Object> responseBody() {
        return (Map<String, Object>) JSON.deserializeUntyped(RestContext.response.responseBody.toString());
    }

    @IsTest
    static void createsApplicationVehicleAndBorrower() {
        Test.setMock(HttpCalloutMock.class, new NhtsaHttpMock());
        mockRequest('POST', '/services/apexrest/financing-applications', VALID_BODY);

        Test.startTest();
        FinancingApplicationApi.create();
        Test.stopTest();

        Assert.areEqual(FinancingApplicationApi.HTTP_CREATED, RestContext.response.statusCode, RestContext.response.responseBody.toString());
        Map<String, Object> body = responseBody();
        Assert.areEqual('Draft', body.get('status'));
        Decimal defaultRate = FinancingApplicationApi.getDefaultInterestRate();
        Assert.areEqual(defaultRate, (Decimal) body.get('interestRate'), 'Le taux vient du Custom Metadata, pas de l\'appelant');
        Assert.areEqual(
            LoanCalculator.monthlyPayment(20000, defaultRate, 48),
            (Decimal) body.get('monthlyPayment'),
            'Le trigger a calculé la mensualité au taux par défaut'
        );

        Financing_Application__c application = [
            SELECT Vehicle__r.VIN__c, Vehicle__r.Make__c, Borrower__r.Email, Borrower__r.LeadSource
            FROM Financing_Application__c
            WHERE Id = :(String) body.get('id')
        ];
        Assert.areEqual(NhtsaHttpMock.HONDA_VIN, application.Vehicle__r.VIN__c);
        Assert.areEqual('HONDA', application.Vehicle__r.Make__c, 'Le nouveau véhicule a été décodé');
        Assert.areEqual('marie.martin@example.com', application.Borrower__r.Email, 'Email normalisé en minuscules');
        Assert.areEqual(FinancingApplicationApi.LEAD_SOURCE_WEB, application.Borrower__r.LeadSource);
    }

    @IsTest
    static void reusesVehicleButNeverAttachesToExistingContact() {
        Test.setMock(HttpCalloutMock.class, new NhtsaHttpMock());
        Vehicle__c vehicle = new Vehicle__c(VIN__c = NhtsaHttpMock.HONDA_VIN);
        insert vehicle;
        Contact borrower = new Contact(LastName = 'Martin', Email = 'marie.martin@example.com');
        insert borrower;
        mockRequest('POST', '/services/apexrest/financing-applications', VALID_BODY);

        Test.startTest();
        FinancingApplicationApi.create();
        Test.stopTest();

        Assert.areEqual(FinancingApplicationApi.HTTP_CREATED, RestContext.response.statusCode);
        Assert.areEqual(1, [SELECT COUNT() FROM Vehicle__c], 'Upsert par VIN : pas de doublon');
        Financing_Application__c application = [SELECT Vehicle__c, Borrower__c FROM Financing_Application__c LIMIT 1];
        Assert.areEqual(vehicle.Id, application.Vehicle__c);
        Assert.areNotEqual(
            borrower.Id,
            application.Borrower__c,
            'Un email non vérifié ne doit pas rattacher le dossier au contact d\'un vrai client'
        );
        Assert.areEqual(2, [SELECT COUNT() FROM Contact], 'Nouveau contact Web créé, à dédoublonner par l\'équipe');
    }

    @IsTest
    static void submitFlagSubmitsApplication() {
        Test.setMock(HttpCalloutMock.class, new NhtsaHttpMock());
        Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(VALID_BODY);
        payload.put('submit', true);
        mockRequest('POST', '/services/apexrest/financing-applications', JSON.serialize(payload));

        Test.startTest();
        FinancingApplicationApi.create();
        Test.stopTest();

        Assert.areEqual('Submitted', responseBody().get('status'));
    }

    @IsTest
    static void missingFieldsReturn400() {
        mockRequest('POST', '/services/apexrest/financing-applications', '{"amount": 20000}');

        FinancingApplicationApi.create();

        Assert.areEqual(FinancingApplicationApi.HTTP_BAD_REQUEST, RestContext.response.statusCode);
        List<Object> errors = (List<Object>) responseBody().get('errors');
        Assert.areEqual(3, errors.size(), String.valueOf(errors));
    }

    @IsTest
    static void malformedJsonReturns400() {
        mockRequest('POST', '/services/apexrest/financing-applications', '{pas du json');

        FinancingApplicationApi.create();

        Assert.areEqual(FinancingApplicationApi.HTTP_BAD_REQUEST, RestContext.response.statusCode);
    }

    @IsTest
    static void validationRuleErrorReturns400AndRollsBack() {
        Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(VALID_BODY);
        payload.put('termMonths', 120);
        mockRequest('POST', '/services/apexrest/financing-applications', JSON.serialize(payload));

        Test.startTest();
        FinancingApplicationApi.create();
        Test.stopTest();

        Assert.areEqual(FinancingApplicationApi.HTTP_BAD_REQUEST, RestContext.response.statusCode);
        Assert.isTrue(String.valueOf(responseBody().get('errors')).contains('12 et 96'), 'Message de la règle de validation renvoyé tel quel');
        Assert.areEqual(0, [SELECT COUNT() FROM Vehicle__c], 'Savepoint : le véhicule créé est annulé');
        Assert.areEqual(0, [SELECT COUNT() FROM Contact], 'Savepoint : l\'emprunteur créé est annulé');
    }

    @IsTest
    static void getReturnsApplication() {
        Financing_Application__c application = TestDataFactory.buildApplications(1, 20000, 5, 48)[0];
        insert application;
        mockRequest('GET', '/services/apexrest/financing-applications/' + application.Id, null);

        FinancingApplicationApi.getById();

        Assert.areEqual(FinancingApplicationApi.HTTP_OK, RestContext.response.statusCode);
        Assert.areEqual(String.valueOf(application.Id), responseBody().get('id'));
    }

    @IsTest
    static void getUnknownIdReturns404() {
        mockRequest('GET', '/services/apexrest/financing-applications/not-an-id', null);

        FinancingApplicationApi.getById();

        Assert.areEqual(FinancingApplicationApi.HTTP_NOT_FOUND, RestContext.response.statusCode);
    }
}
