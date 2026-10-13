// Crée l'utilisateur technique utilisé par le formulaire web (OAuth Client Credentials).
// Licence "Salesforce Integration" : API uniquement, pas d'accès à l'interface.
// Usage : sf apex run --file scripts/apex/create-integration-user.apex
String domain = URL.getOrgDomainUrl().getHost().substringBefore('.');
User integrationUser = new User(
    FirstName = 'Financing',
    LastName = 'Integration',
    Alias = 'finint',
    Email = UserInfo.getUserEmail(),
    Username = 'financing.integration@' + domain + '.com',
    ProfileId = [SELECT Id FROM Profile WHERE Name = 'Minimum Access - API Only Integrations' LIMIT 1].Id,
    EmailEncodingKey = 'UTF-8',
    LanguageLocaleKey = 'en_US',
    LocaleSidKey = 'fr_FR',
    TimeZoneSidKey = 'Europe/Paris'
);
insert integrationUser;

insert new PermissionSetLicenseAssign(
    AssigneeId = integrationUser.Id,
    PermissionSetLicenseId = [SELECT Id FROM PermissionSetLicense WHERE DeveloperName = 'SalesforceAPIIntegrationPsl' LIMIT 1].Id
);
insert new PermissionSetAssignment(
    AssigneeId = integrationUser.Id,
    PermissionSetId = [SELECT Id FROM PermissionSet WHERE Name = 'Financing_Integration' LIMIT 1].Id
);
System.debug('Integration user: ' + integrationUser.Username);
