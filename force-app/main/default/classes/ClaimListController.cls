public with sharing class ClaimListController {

    // ── Get single Claim record for detail view ────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static Claim getClaimRecord(Id claimId) {
        try {
            return [
                SELECT Id, Name, AccountId, Account.Name, ClaimType,
                       EstimatedAmount, ActualAmount, ApprovedAmount,
                       Severity, FnolChannel, IncidentSite, TotalClaimedAmount,
                       FinancialAuthorityStatus, RelatedClaimId, CurrencyIsoCode,
                       Confidence_Score__c, Auto_Approved__c, Fruad_Flag__c,
                       Evidence_Completed__c, AI_Summary__c,
                       PolicyNumberId, InsuredAssetId, InsuredAsset.Name,
                       LossType, InitiationDate, AssessmentDate, FinalizedDate,
                       Status, ClaimReason, IncidentId, TotalAdjustedAmount
                FROM Claim
                WHERE Id = :claimId
                LIMIT 1
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error loading claim: ' + e.getMessage());
        }
    }

    // ── Get Claim Items related list ───────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static List<ClaimItem> getClaimItems(Id claimId) {
        try {
            return [
                SELECT Id, Name, ClaimId,
                       AssetId,                    Asset.Name,
                       FaultDate,                  AssetUsageValue,
                       VehicleId,                  Vehicle.Name,
                       Description,
                       ProductId,                  Product.Name,
                       InsurancePolicyCoverageId,  InsurancePolicyCoverage.Name,
                       RepairDate,                 AssetUsageUnitOfMeasure
                FROM ClaimItem
                WHERE ClaimId = :claimId
                ORDER BY Name ASC
                LIMIT 200
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error loading claim items: ' + e.getMessage());
        }
    }

    // ── File / Note wrapper ────────────────────────────────────────────────────

    public class FileWrapper {
        @AuraEnabled public String  contentDocumentId { get; set; }
        @AuraEnabled public String  versionId         { get; set; }
        @AuraEnabled public String  title             { get; set; }
        @AuraEnabled public String  fileType          { get; set; }
        @AuraEnabled public Long    fileSize          { get; set; }
        @AuraEnabled public String  createdDate       { get; set; }
        @AuraEnabled public String  downloadUrl       { get; set; }
        @AuraEnabled public String  viewUrl           { get; set; }
        @AuraEnabled public Boolean isNote            { get; set; }
    }

    // ── Get Notes & Attachments (ContentDocumentLink) ──────────────────────────

    @AuraEnabled(cacheable=true)
    public static List<FileWrapper> getClaimFiles(Id claimId) {
        try {
            List<ContentDocumentLink> links = [
                SELECT ContentDocument.Id,
                       ContentDocument.Title,
                       ContentDocument.FileType,
                       ContentDocument.ContentSize,
                       ContentDocument.CreatedDate,
                       ContentDocument.LatestPublishedVersionId
                FROM ContentDocumentLink
                WHERE LinkedEntityId = :claimId
                ORDER BY ContentDocument.CreatedDate DESC
                LIMIT 200
            ];

            String orgBase = URL.getOrgDomainUrl().toExternalForm();
            List<FileWrapper> result = new List<FileWrapper>();

            for (ContentDocumentLink cdl : links) {
                ContentDocument doc = cdl.ContentDocument;
                FileWrapper w       = new FileWrapper();
                w.contentDocumentId = doc.Id;
                w.versionId         = doc.LatestPublishedVersionId;
                w.title             = doc.Title;
                w.fileType          = doc.FileType;
                w.fileSize          = doc.ContentSize;
                w.createdDate       = doc.CreatedDate != null ? String.valueOf(doc.CreatedDate) : null;
                w.isNote            = (doc.FileType == 'SNOTE');
                w.downloadUrl       = orgBase + '/sfc/servlet.shepherd/version/download/' + doc.LatestPublishedVersionId;
                w.viewUrl           = orgBase + '/sfc/servlet.shepherd/document/download/' + doc.Id;
                result.add(w);
            }

            return result;
        } catch (Exception e) {
            throw new AuraHandledException('Error loading claim files: ' + e.getMessage());
        }
    }

    // ── Get Claims for list view ───────────────────────────────────────────────

    @AuraEnabled(cacheable=false)
    public static List<Claim> getClaims(String dateFilter, String statusFilter, String searchTerm) {
        try {
            Map<String, String> dateLiteralMap = new Map<String, String>{
                'TODAY'      => 'TODAY',
                'YESTERDAY'  => 'YESTERDAY',
                'THIS_MONTH' => 'THIS_MONTH',
                'LAST_MONTH' => 'LAST_MONTH'
            };
            String dateLiteral = dateLiteralMap.containsKey(dateFilter)
                ? dateLiteralMap.get(dateFilter)
                : 'THIS_MONTH';

            List<String> conditions = new List<String>();
            conditions.add('CreatedDate = ' + dateLiteral);

            if (!String.isBlank(statusFilter)) {
                String safeStatus = String.escapeSingleQuotes(statusFilter.trim());
                conditions.add('Status = \'' + safeStatus + '\'');
            }

            String searchLike = null;
            if (!String.isBlank(searchTerm)) {
                searchLike = '%' + searchTerm.trim() + '%';
                conditions.add('Name LIKE :searchLike');
            }

            String soql =
                'SELECT Id, Name, AccountId, Account.Name, Status, ClaimType, EstimatedAmount, CreatedDate ' +
                'FROM Claim ' +
                'WHERE ' + String.join(conditions, ' AND ') + ' ' +
                'ORDER BY CreatedDate DESC ' +
                'LIMIT 200';

            return Database.query(soql);

        } catch (Exception e) {
            throw new AuraHandledException('Error loading claims: ' + e.getMessage());
        }
    }
}