@IsTest
public class TestDataFactory {
    public static List<Financing_Application__c> buildApplications(Integer count, Decimal amount, Decimal annualRatePercent, Integer termMonths) {
        List<Financing_Application__c> applications = new List<Financing_Application__c>();
        for (Integer i = 0; i < count; i++) {
            applications.add(
                new Financing_Application__c(
                    Amount__c = amount,
                    Interest_Rate__c = annualRatePercent,
                    Term_Months__c = termMonths,
                    Status__c = 'Draft'
                )
            );
        }
        return applications;
    }

    /** Utilisateur standard qui n'a que le permission set Financing_User : vérifie que les droits suffisent. */
    public static User createFinancingUser() {
        Profile standardProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        String uniqueKey = String.valueOf(Crypto.getRandomInteger()).replace('-', '');
        User financingUser = new User(
            Alias = 'fin' + uniqueKey.left(5),
            Email = 'financing.user@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Financing User',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'fr_FR',
            ProfileId = standardProfile.Id,
            TimeZoneSidKey = 'Europe/Paris',
            Username = 'financing.user.' + uniqueKey + '@example.com'
        );
        // runAs(admin) : isole le DML sur les objets de setup (User, PermissionSetAssignment) -> pas de "Mixed DML"
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert financingUser;
            PermissionSet permissionSet = [SELECT Id FROM PermissionSet WHERE Name = 'Financing_User' LIMIT 1];
            insert new PermissionSetAssignment(AssigneeId = financingUser.Id, PermissionSetId = permissionSet.Id);
        }
        return financingUser;
    }
}
