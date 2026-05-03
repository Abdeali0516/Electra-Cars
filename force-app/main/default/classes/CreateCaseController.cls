public without sharing class CreateCaseController {

    public class UserInformation {
        @AuraEnabled public String phone { get; set; }
        @AuraEnabled public Id contactId { get; set; }
        @AuraEnabled public Id accountId { get; set; }
    }

    public class CaseResult {
        @AuraEnabled public Id caseId { get; set; }
        @AuraEnabled public String caseNumber { get; set; }
        @AuraEnabled public Boolean success { get; set; }
        @AuraEnabled public String errorMessage { get; set; }
    }

    @AuraEnabled(cacheable=true)
    public static UserInformation getCurrentUserInfo() {
        UserInformation userInfo = new UserInformation();

        try {
            Id userId = System.UserInfo.getUserId();
            User currentUser = [
                SELECT Id, Phone, ContactId, Contact.AccountId, Contact.Phone
                FROM User
                WHERE Id = :userId
                LIMIT 1
            ];

            if (currentUser != null && currentUser.ContactId != null) {
                userInfo.contactId = currentUser.ContactId;
                userInfo.accountId = currentUser.Contact.AccountId;

                if (String.isNotBlank(currentUser.Contact.Phone)) {
                    userInfo.phone = currentUser.Contact.Phone;
                } else if (String.isNotBlank(currentUser.Phone)) {
                    userInfo.phone = currentUser.Phone;
                }
            }
        } catch (Exception e) {
            System.debug('Error fetching user info: ' + e.getMessage());
        }

        return userInfo;
    }

    @AuraEnabled
    public static CaseResult createCase(
        String subject,
        String description,
        String suppliedPhone,
        String priority,
        Id contactId,
        Id accountId
    ) {
        CaseResult result = new CaseResult();

        try {
            User assignedUser;
            try {
                assignedUser = [
                    SELECT Id, Name
                    FROM User
                    WHERE Username = 'pankaj@360is-prod.com'
                    AND IsActive = true
                    LIMIT 1
                ];
            } catch (Exception e) {
                System.debug('Warning: Could not find assigned user: ' + e.getMessage());
            }

            Case newCase = new Case();
            newCase.Subject = subject;
            newCase.Origin = 'Web';
            newCase.Status = 'New';
            newCase.Priority = priority;
            newCase.Description = description;
            newCase.SuppliedPhone = suppliedPhone;

            if (assignedUser != null) {
                newCase.OwnerId = assignedUser.Id;
            }
            if (contactId != null) {
                newCase.ContactId = contactId;
            }
            if (accountId != null) {
                newCase.AccountId = accountId;
            }

            insert newCase;

            Case insertedCase = [
                SELECT Id, CaseNumber
                FROM Case
                WHERE Id = :newCase.Id
                LIMIT 1
            ];

            result.caseId = insertedCase.Id;
            result.caseNumber = insertedCase.CaseNumber;
            result.success = true;

        } catch (Exception e) {
            result.success = false;
            result.errorMessage = e.getMessage();
            System.debug('Error creating case: ' + e.getMessage() + '\n' + e.getStackTraceString());
        }

        return result;
    }

    @AuraEnabled
    public static void linkFilesToCase(Id caseId, List<Id> fileIds) {
        try {
            if (caseId == null || fileIds == null || fileIds.isEmpty()) {
                return;
            }

            List<ContentDocumentLink> links = new List<ContentDocumentLink>();

            for (Id fileId : fileIds) {
                ContentDocumentLink link = new ContentDocumentLink();
                link.ContentDocumentId = fileId;
                link.LinkedEntityId = caseId;
                link.ShareType = 'V';
                link.Visibility = 'AllUsers';
                links.add(link);
            }

            if (!links.isEmpty()) {
                insert links;
            }

        } catch (Exception e) {
            System.debug('Error linking files to case: ' + e.getMessage());
            throw new AuraHandledException('Failed to link attachments: ' + e.getMessage());
        }
    }
}