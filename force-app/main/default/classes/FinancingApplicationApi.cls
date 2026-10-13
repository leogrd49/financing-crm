/**
 * API REST entrante : création et suivi d'un dossier de financement depuis l'extérieur.
 *
 *   POST /services/apexrest/financing-applications
 *   GET  /services/apexrest/financing-applications/{id}
 *
 * - Le véhicule est upserté par VIN (External ID) : pas de doublon, et un nouveau VIN est décodé via NHTSA.
 * - L'emprunteur est retrouvé par email, sinon créé.
 * - Tout s'exécute en mode utilisateur (WITH USER_MODE / as user) : l'appelant n'a que les droits
 *   de son permission set.
 * - Tout ou rien : en cas d'erreur, un savepoint annule ce qui a été créé.
 */
@RestResource(urlMapping='/financing-applications/*')
global with sharing class FinancingApplicationApi {
    @TestVisible
    private static final Integer HTTP_CREATED = 201;
    @TestVisible
    private static final Integer HTTP_OK = 200;
    @TestVisible
    private static final Integer HTTP_BAD_REQUEST = 400;
    @TestVisible
    private static final Integer HTTP_NOT_FOUND = 404;

    global class ApplicationRequest {
        public Decimal amount;
        public Integer termMonths;
        public Decimal interestRate;
        public String vin;
        public Borrower borrower;
        public Boolean submit;
    }

    global class Borrower {
        public String firstName;
        public String lastName;
        public String email;
        public String phone;
    }

    @HttpPost
    global static void create() {
        ApplicationRequest input;
        try {
            input = (ApplicationRequest) JSON.deserialize(RestContext.request.requestBody.toString(), ApplicationRequest.class);
        } catch (Exception e) {
            respondError(HTTP_BAD_REQUEST, new List<String>{ 'JSON invalide : ' + e.getMessage() });
            return;
        }

        List<String> errors = validate(input);
        if (!errors.isEmpty()) {
            respondError(HTTP_BAD_REQUEST, errors);
            return;
        }

        Savepoint savepoint = Database.setSavepoint();
        try {
            Vehicle__c vehicle = new Vehicle__c(VIN__c = input.vin.trim().toUpperCase());
            upsert as user vehicle VIN__c;

            Financing_Application__c application = new Financing_Application__c(
                Amount__c = input.amount,
                Term_Months__c = input.termMonths,
                Interest_Rate__c = input.interestRate,
                Vehicle__c = vehicle.Id,
                Borrower__c = findOrCreateBorrower(input.borrower),
                Status__c = input.submit == true ? 'Submitted' : 'Draft'
            );
            insert as user application;

            respond(HTTP_CREATED, toResponse(application.Id));
        } catch (DmlException e) {
            Database.rollback(savepoint);
            List<String> messages = new List<String>();
            for (Integer i = 0; i < e.getNumDml(); i++) {
                messages.add(e.getDmlMessage(i));
            }
            respondError(HTTP_BAD_REQUEST, messages);
        }
    }

    @HttpGet
    global static void getById() {
        String applicationId = RestContext.request.requestURI.substringAfterLast('/');
        Map<String, Object> body = String.isBlank(applicationId) ? null : toResponse(applicationId);
        if (body == null) {
            respondError(HTTP_NOT_FOUND, new List<String>{ 'Dossier introuvable : ' + applicationId });
            return;
        }
        respond(HTTP_OK, body);
    }

    private static List<String> validate(ApplicationRequest input) {
        List<String> errors = new List<String>();
        if (input == null) {
            return new List<String>{ 'Corps de requête vide.' };
        }
        if (input.amount == null) {
            errors.add('amount est obligatoire.');
        }
        if (input.termMonths == null) {
            errors.add('termMonths est obligatoire.');
        }
        if (input.interestRate == null) {
            errors.add('interestRate est obligatoire.');
        }
        if (String.isBlank(input.vin)) {
            errors.add('vin est obligatoire.');
        }
        if (input.borrower == null || String.isBlank(input.borrower.lastName) || String.isBlank(input.borrower.email)) {
            errors.add('borrower.lastName et borrower.email sont obligatoires.');
        }
        return errors;
    }

    private static Id findOrCreateBorrower(Borrower borrower) {
        String email = borrower.email.trim().toLowerCase();
        List<Contact> existing = [SELECT Id FROM Contact WHERE Email = :email WITH USER_MODE LIMIT 1];
        if (!existing.isEmpty()) {
            return existing[0].Id;
        }
        Contact contact = new Contact(FirstName = borrower.firstName, LastName = borrower.lastName, Email = email, Phone = borrower.phone);
        insert as user contact;
        return contact.Id;
    }

    /** @return null si le dossier n'existe pas ou n'est pas visible pour l'appelant */
    private static Map<String, Object> toResponse(String applicationId) {
        if (!(applicationId instanceof Id)) {
            return null;
        }
        List<Financing_Application__c> found = [
            SELECT Id, Name, Status__c, Amount__c, Term_Months__c, Interest_Rate__c, Monthly_Payment__c, Risk_Score__c, Vehicle__r.VIN__c
            FROM Financing_Application__c
            WHERE Id = :applicationId
            WITH USER_MODE
        ];
        if (found.isEmpty()) {
            return null;
        }
        Financing_Application__c application = found[0];
        return new Map<String, Object>{
            'id' => application.Id,
            'name' => application.Name,
            'status' => application.Status__c,
            'amount' => application.Amount__c,
            'termMonths' => application.Term_Months__c,
            'interestRate' => application.Interest_Rate__c,
            'monthlyPayment' => application.Monthly_Payment__c,
            'riskScore' => application.Risk_Score__c,
            'vin' => application.Vehicle__r?.VIN__c
        };
    }

    private static void respond(Integer statusCode, Object body) {
        RestContext.response.statusCode = statusCode;
        RestContext.response.addHeader('Content-Type', 'application/json');
        RestContext.response.responseBody = Blob.valueOf(JSON.serialize(body));
    }

    private static void respondError(Integer statusCode, List<String> errors) {
        respond(statusCode, new Map<String, Object>{ 'errors' => errors });
    }
}
