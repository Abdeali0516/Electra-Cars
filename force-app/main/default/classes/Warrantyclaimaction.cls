/**
 * WarrantyClaimAction
 * Agentforce InvocableMethod - Toyota True Warranty multi-step Claim creation.
 *
 * KEY DESIGN DECISIONS:
 *   All Id and Date fields on WarrantyClaimRequest are declared as String
 *   because Agentforce sends "" for unresolved Ids (which Apex Id type rejects).
 *   safeId(String) converts "" or null to null safely.
 *
 * RECORD CREATION ORDER:
 *   1. Claim
 *   2. ClaimItem + ClaimCoverage
 *   3. WorkOrder
 *   4. ContentNote / ContentDocumentLink
 *
 * API VERSION: 62.0 (Spring 26)
 */
global without sharing class Warrantyclaimaction {

    public class WarrantyClaimException extends Exception {}

    // =========================================================================
    // SECTION A - PRIVATE HELPERS
    // =========================================================================

    private static Id safeId(String val) {
        if (String.isBlank(val)) return null;
        try { return (Id) val; }
        catch (Exception e) { return null; }
    }

    private static Date safeDate(String val) {
        if (String.isBlank(val)) return null;
        try {
            String dateOnly = val.contains('T') ? val.substringBefore('T') : val;
            return Date.valueOf(dateOnly);
        } catch (Exception e) { return null; }
    }

    private static String generateClaimNumber() {
        String datePart = Datetime.now().format('yyyyMMdd');
        Integer raw = Math.abs(Math.mod(Math.round(Math.random() * 1000000), 1000000));
        String randomPart = String.valueOf(raw).leftPad(6, '0');
        return 'WC-' + datePart + '-' + randomPart;
    }

    private static void validateClaimInput(
        String  affectedComponent,
        String  faultDescription,
        Boolean isVehicleDrivable,
        String  repairTypeRequested
    ) {
        System.debug(LoggingLevel.ERROR, '[WCA] validateClaimInput - component=' + affectedComponent
            + ' drivable=' + isVehicleDrivable + ' repairType=' + repairTypeRequested
            + ' descLength=' + (faultDescription != null ? faultDescription.length() : 0));
        if (String.isBlank(affectedComponent) || affectedComponent == 'Not specified')
            throw new WarrantyClaimException('Affected component / system is required.');
        if (String.isBlank(faultDescription)
            || faultDescription == 'Not specified'
            || faultDescription.trim().length() < 20)
            throw new WarrantyClaimException('Please provide a detailed fault description (minimum 20 characters).');
        if (isVehicleDrivable == null)
            throw new WarrantyClaimException('Please indicate whether the vehicle is currently drivable.');
        if (String.isBlank(repairTypeRequested))
            throw new WarrantyClaimException('Repair type requested is required.');
    }

    private static Id resolveDealerId(String dealerAccountIdStr, String dealerCode) {
        Id directId = safeId(dealerAccountIdStr);
        if (directId != null) return directId;
        if (String.isBlank(dealerCode)) return null;
        List<Account> dealers = [
            SELECT Id FROM Account
            WHERE AccountNumber = :dealerCode
            AND Type = 'Dealer'
            LIMIT 1
        ];
        return dealers.isEmpty() ? null : dealers[0].Id;
    }

    private static Claim buildClaim(
        String  affectedComponent,
        String  faultDescription,
        Boolean isVehicleDrivable,
        Id      customerAccountId,
        Id      resolvedDealerId,
        Decimal currentOdometerReading,
        Decimal warrantyMileageLimit,
        Boolean servicedAtAuthorisedDealer,
        Id      vehicleId
    ) {
        Boolean mileageExceeded = (warrantyMileageLimit != null
                                && warrantyMileageLimit > 0
                                && currentOdometerReading != null
                                && currentOdometerReading > warrantyMileageLimit);

        String claimReason = affectedComponent + ': ' + faultDescription;

        if (mileageExceeded) {
            claimReason += ' [ODOMETER LIMIT EXCEEDED: '
                + currentOdometerReading.toPlainString()
                + ' km vs limit ' + warrantyMileageLimit.toPlainString() + ' km]';
        }
        if (servicedAtAuthorisedDealer == false) {
            claimReason += ' [NOTE: Last service not at authorised dealer - partially covered]';
        }
        if (resolvedDealerId != null) {
            claimReason += ' [Dealer Id: ' + resolvedDealerId + ']';
        }

        Claim c = new Claim();
        c.Name                  = generateClaimNumber();
        c.IsAuthoritiesNotified = false;
        c.IsInhabitable         = false;
        c.IsDrivable            = isVehicleDrivable;
        c.AccountId             = customerAccountId;
        c.Status                = 'New';
        c.ClaimType             = 'Warranty Claim';
        c.Severity              = (isVehicleDrivable == false) ? 'High' : 'Medium';
        c.ClaimReason           = claimReason;
        if (vehicleId != null) {
            c.Vehicle__c = vehicleId;
        }
        return c;
    }

    // =========================================================================
    // SECTION B - @AuraEnabled METHODS
    // =========================================================================

    @AuraEnabled(cacheable=true)
    public static List<Account> getAccounts() {
        return [
            SELECT Id, Name, AccountNumber
            FROM Account
            ORDER BY Name ASC
            LIMIT 200
        ];
    }

    @AuraEnabled
    public static Map<String, String> createWarrantyClaim(
        String  affectedComponent,
        String  faultDescription,
        Boolean isVehicleDrivable,
        String  repairTypeRequested,
        Decimal currentOdometerReading,
        String  customerAccountId,
        String  dealerAccountId,
        String  dealerCode,
        Decimal warrantyMileageLimit,
        String  vinNumber
    ) {
        System.debug(LoggingLevel.ERROR, '[WCA] createWarrantyClaim START - affectedComponent=' + affectedComponent
            + ' isVehicleDrivable=' + isVehicleDrivable
            + ' repairTypeRequested=' + repairTypeRequested
            + ' currentOdometerReading=' + currentOdometerReading
            + ' customerAccountId=' + customerAccountId
            + ' dealerAccountId=' + dealerAccountId
            + ' dealerCode=' + dealerCode);
        validateClaimInput(
            affectedComponent, faultDescription,
            isVehicleDrivable, repairTypeRequested
        );

        Id custId         = safeId(customerAccountId);
        Id resolvedDealer = resolveDealerId(dealerAccountId, dealerCode);
        System.debug(LoggingLevel.ERROR, '[WCA] Validation passed. custId=' + custId + ' resolvedDealer=' + resolvedDealer);

        Id vehicleId;
        if (!String.isBlank(vinNumber)) {
            List<Vehicle> vehicles = [
                SELECT Id FROM Vehicle
                WHERE VehicleIdentificationNumber = :vinNumber
                LIMIT 1
            ];
            if (!vehicles.isEmpty()) {
                vehicleId = vehicles[0].Id;
            }
        }

        Claim claim = buildClaim(
            affectedComponent, faultDescription,
            isVehicleDrivable, custId,
            resolvedDealer, currentOdometerReading,
            warrantyMileageLimit, null, vehicleId
        );
        insert claim;
        System.debug(LoggingLevel.ERROR, '[WCA] Claim inserted: ' + claim.Id + ' / ' + claim.Name);
        // EventBus.publish(new Claim_Submitted_Event__e(Claim_Id__c = claim.Id));

        Claim inserted = [
            SELECT Id, Name, Status, ClaimType, ClaimReason
            FROM Claim WHERE Id = :claim.Id LIMIT 1
        ];

        return new Map<String, String>{
            'claimId'          => inserted.Id,
            'claimNumber'      => inserted.Name,
            'claimStatus'      => inserted.Status,
            'claimDescription' => inserted.ClaimReason
        };
    }

    @AuraEnabled
    public static void addClaimItems(
        Id     claimId,
        String assetIdStr,
        String assetWarrantyIdStr,
        String affectedComponent,
        String claimItemsJson
    ) {
        if (claimId == null)
            throw new AuraHandledException('Claim Id is required to add claim items.');
        if (String.isBlank(claimItemsJson))
            throw new AuraHandledException('Claim item data is required.');

        List<Object> rawItems;
        try {
            rawItems = (List<Object>) JSON.deserializeUntyped(claimItemsJson);
        } catch (Exception ex) {
            throw new AuraHandledException('Invalid claim item format: ' + ex.getMessage());
        }

        Id assetId         = safeId(assetIdStr);
        Id assetWarrantyId = safeId(assetWarrantyIdStr);

        List<ClaimItem> itemsToInsert = new List<ClaimItem>();
        for (Object rawObj : rawItems) {
            Map<String, Object> m = (Map<String, Object>) rawObj;

            String itemName = (String) m.get('itemName');
            if (String.isBlank(itemName))
                itemName = String.isBlank(affectedComponent) ? 'Warranty Item' : affectedComponent;

            String itemDesc = (String) m.get('itemDescription');
            String partNum  = (String) m.get('partNumber');
            if (!String.isBlank(partNum))
                itemDesc = (String.isBlank(itemDesc) ? '' : itemDesc + ' | ') + 'Part No: ' + partNum;

            Object qtyObj = m.get('quantity');
            if (qtyObj != null) {
                String qtyStr = String.valueOf(qtyObj);
                if (!String.isBlank(qtyStr) && qtyStr != 'null')
                    itemDesc = (String.isBlank(itemDesc) ? '' : itemDesc + ' | ') + 'Qty: ' + qtyStr;
            }

            ClaimItem ci   = new ClaimItem();
            ci.ClaimId     = claimId;
            ci.Name        = itemName;
            ci.Description = itemDesc;
            ci.AssetId     = assetId;

            String faultDateStr = (String) m.get('faultDate');
            if (!String.isBlank(faultDateStr)) {
                try { ci.FaultDate = Date.valueOf(faultDateStr); }
                catch (Exception ex) { /* skip */ }
            }
            itemsToInsert.add(ci);
        }

        if (itemsToInsert.isEmpty()) return;
        insert itemsToInsert;

        if (assetWarrantyId != null) {
            List<ClaimCoverage> coverages = new List<ClaimCoverage>();
            for (ClaimItem ci : itemsToInsert) {
                ClaimCoverage cc   = new ClaimCoverage();
                cc.ClaimId         = claimId;
                cc.ClaimItemId     = ci.Id;
                cc.AssetWarrantyId = assetWarrantyId;
                cc.CoverageType    = 'Warranty';
                cc.Status          = 'Active';
                coverages.add(cc);
            }
            insert coverages;
        }
    }

    @AuraEnabled
    public static Id createWorkOrder(
        Id      claimId,
        String  assetIdStr,
        String  dealerAccountIdStr,
        String  affectedComponent,
        String  repairTypeRequested,
        String  faultDescription,
        Boolean isVehicleDrivable
    ) {
        if (claimId == null)
            throw new AuraHandledException('Claim Id is required to create a Work Order.');

        String subject = String.isBlank(affectedComponent) ? 'Warranty Repair' : affectedComponent;
        if (!String.isBlank(repairTypeRequested))
            subject += ' - ' + repairTypeRequested;

        String woDesc = (String.isBlank(faultDescription) ? '' : faultDescription)
                        + ' [Claim Id: ' + claimId + ']';

        WorkOrder wo   = new WorkOrder();
        wo.AssetId     = safeId(assetIdStr);
        wo.Subject     = subject;
        wo.Description = woDesc;
        wo.Status      = 'New';
        wo.Priority    = (isVehicleDrivable == false) ? 'High' : 'Medium';
        insert wo;
        return wo.Id;
    }

    @AuraEnabled
    public static void addNote(Id claimId, String noteTitle, String noteBody) {
        if (claimId == null)
            throw new AuraHandledException('Claim Id is required to add a note.');
        if (String.isBlank(noteBody))
            throw new AuraHandledException('Note body cannot be empty.');

        ContentNote note = new ContentNote();
        note.Title   = String.isBlank(noteTitle) ? 'Warranty Claim Note' : noteTitle;
        note.Content = Blob.valueOf(noteBody.escapeHtml4());
        insert note;

        ContentDocumentLink cdl = new ContentDocumentLink();
        cdl.ContentDocumentId = note.Id;
        cdl.LinkedEntityId    = claimId;
        cdl.ShareType         = 'V';
        cdl.Visibility        = 'AllUsers';
        insert cdl;
    }

    @AuraEnabled
    public static void linkAttachmentToClaim(Id claimId, Id contentDocumentId) {
        if (claimId == null || contentDocumentId == null)
            throw new AuraHandledException('Claim Id and Content Document Id are both required.');

        List<ContentDocumentLink> existing = [
            SELECT Id FROM ContentDocumentLink
            WHERE LinkedEntityId = :claimId
            AND ContentDocumentId = :contentDocumentId
            LIMIT 1
        ];
        if (!existing.isEmpty()) return;

        ContentDocumentLink cdl = new ContentDocumentLink();
        cdl.ContentDocumentId = contentDocumentId;
        cdl.LinkedEntityId    = claimId;
        cdl.ShareType         = 'V';
        cdl.Visibility        = 'AllUsers';
        insert cdl;
    }

    @TestVisible
    global static Map<String, String> submitFullClaim(WarrantyClaimRequest req) {
        validateClaimInput(
            req.affectedComponent, req.faultDescription,
            req.isVehicleDrivable, req.repairTypeRequested
        );

        Id resolvedDealer = resolveDealerId(req.dealerAccountId, req.dealerCode);

        Id vehicleId;
        if (!String.isBlank(req.vinNumber)) {
            List<Vehicle> vehicles = [
                SELECT Id FROM Vehicle
                WHERE VehicleIdentificationNumber = :req.vinNumber
                LIMIT 1
            ];
            if (!vehicles.isEmpty()) {
                vehicleId = vehicles[0].Id;
            }
        }

        Id custId = safeId(req.customerAccountId);

        Claim claim = buildClaim(
            req.affectedComponent, req.faultDescription,
            req.isVehicleDrivable, custId,
            resolvedDealer, req.currentOdometerReading,
            req.warrantyMileageLimit, req.servicedAtAuthorisedDealer, vehicleId
        );
        insert claim;
        // EventBus.publish(new Claim_Submitted_Event__e(Claim_Id__c = claim.Id));

        if (!String.isBlank(req.claimItemsJson)) {
            addClaimItems(
                claim.Id, req.assetId, req.assetWarrantyId,
                req.affectedComponent, req.claimItemsJson
            );
        }

        if (!String.isBlank(req.repairTypeRequested)) {
            createWorkOrder(
                claim.Id, req.assetId,
                req.dealerAccountId, req.affectedComponent,
                req.repairTypeRequested, req.faultDescription,
                req.isVehicleDrivable
            );
        }

        if (!String.isBlank(req.noteBody)) {
            addNote(claim.Id, req.noteTitle, req.noteBody);
        }

        Claim inserted = [
            SELECT Id, Name, Status, ClaimType, ClaimReason
            FROM Claim WHERE Id = :claim.Id LIMIT 1
        ];

        return new Map<String, String>{
            'claimId'          => inserted.Id,
            'claimNumber'      => inserted.Name,
            'claimStatus'      => inserted.Status,
            'claimDescription' => inserted.ClaimReason
        };
    }

    // =========================================================================
    // SECTION C - @InvocableMethod
    // =========================================================================

    @JsonAccess(serializable='always' deserializable='always')
    global class ActionInput {
        @InvocableVariable(label='Claim Data' required=true)
        global WarrantyClaimRequest claimData;
    }

    @InvocableMethod(
        label='Submit Toyota True Warranty Claim'
        description='Creates Claim, ClaimItems, ClaimCoverage, WorkOrder, and Notes in Automotive Cloud.'
        category='Warranty'
    )
    global static List<WarrantyClaimResponse> submitClaim(List<ActionInput> requests) {
        List<WarrantyClaimResponse> responses = new List<WarrantyClaimResponse>();
        for (ActionInput inp : requests) {
            responses.add(processClaim(inp.claimData));
        }
        return responses;
    }

    @TestVisible
    private static WarrantyClaimResponse processClaim(WarrantyClaimRequest req) {
        WarrantyClaimResponse resp = new WarrantyClaimResponse();
        resp.submissionTimestamp   = Datetime.now().format('dd MMM yyyy, hh:mm a z');
        resp.claimType             = 'Warranty Claim';
        resp.claimDate             = Date.today();

        Boolean userSubmitted = (req != null
            && req.submitRequested != null
            && (req.submitRequested == 'true' || req.submitRequested == 'Yes'));

        if (!userSubmitted) {
            resp.claimStatus      = 'Pending';
            resp.claimNumber      = 'N/A';
            resp.claimDescription = 'Awaiting user input via warranty claim form.';
            return resp;
        }

        try {
            Map<String, String> result = submitFullClaim(req);
            resp.claimId     = result.get('claimId');
            resp.claimNumber = result.get('claimNumber');
            resp.claimStatus = result.get('claimStatus');
            String rsaDesc   = result.get('claimDescription');
            if (req.isVehicleDrivable == false) {
                rsaDesc = rsaDesc + ' [RSA_ELIGIBLE: true - vehicle is not drivable]';
            }
            resp.claimDescription = rsaDesc;
        } catch (WarrantyClaimException e) {
            resp.claimStatus      = 'Rejected';
            resp.claimNumber      = 'N/A';
            resp.claimDescription = e.getMessage();
        } catch (Exception e) {
            resp.claimStatus      = 'Error';
            resp.claimNumber      = 'N/A';
            resp.claimDescription = 'Unexpected error: ' + e.getMessage();
        }
        return resp;
    }
}