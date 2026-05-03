/**
 * WarrantyClaimRequest
 * Agentforce Custom Lightning Type (CLT) - INPUT schema.
 * Spring 26 / API v62.0
 *
 * CRITICAL DESIGN RULE - ALL Id FIELDS ARE String TYPE:
 *   Agentforce sends "" (empty string) for any Id field it cannot resolve.
 *   Apex Id type rejects "" with UNKNOWN_EXCEPTION / Invalid id.
 *   Solution: declare all Id fields as String here. The Apex action
 *   casts them to Id only after a null/blank check.
 *
 * CRITICAL DESIGN RULE - ALL Date FIELDS ARE String TYPE:
 *   Agentforce sends dates as "2026-04-01" strings from its context.
 *   Apex Date type deserialization can fail on timezone variations.
 *   Solution: declare as String, parse in Apex only when needed.
 *
 * RULE: Every field here must match a key emitted by _dispatchValueChange()
 *       in the LWC. Any mismatch causes "variable not found" in Agentforce.
 */
@JsonAccess(serializable='always' deserializable='always')
global class WarrantyClaimRequest {

    // =========================================================================
    // SECTION 1 - Vehicle (auto-filled by Agentforce)
    // =========================================================================
    @AuraEnabled global String  vehicleId;
    @AuraEnabled global String  vinNumber;
    @AuraEnabled global String  registrationNumber;
    @AuraEnabled global String  vehiclePurchaseDate;
    @AuraEnabled global String  vehicleColour;
    @AuraEnabled global String  vehicleType;

    // =========================================================================
    // SECTION 2 - VehicleDefinition (auto-filled)
    // =========================================================================
    @AuraEnabled global String  vehicleMake;
    @AuraEnabled global String  vehicleModel;
    @AuraEnabled global Integer modelYear;
    @AuraEnabled global String  fuelType;
    @AuraEnabled global String  transmissionType;

    // =========================================================================
    // SECTION 3 - Asset (auto-filled)
    // Id declared as String - Agentforce sends "" when not resolved
    // =========================================================================
    @AuraEnabled global String  assetId;

    // =========================================================================
    // SECTION 4 - AssetWarranty (auto-filled)
    // =========================================================================
    @AuraEnabled global String  assetWarrantyId;
    @AuraEnabled global String  warrantyStartDate;
    @AuraEnabled global String  warrantyEndDate;
    @AuraEnabled global String  warrantyType;
    @AuraEnabled global String  serviceCertificateNumber;

    // =========================================================================
    // SECTION 5 - WarrantyTerm (auto-filled)
    // warrantyTermId declared as String - Agentforce sends "" when not resolved
    // =========================================================================
    @AuraEnabled global String  warrantyTermId;
    @AuraEnabled global String  warrantyTermName;
    @AuraEnabled global Integer warrantyDurationMonths;
    @AuraEnabled global Boolean isWarrantyTransferable;
    @AuraEnabled global Decimal warrantyMileageLimit;

    // =========================================================================
    // SECTION 6 - Account Customer (auto-filled)
    // customerAccountId declared as String - cast to Id in Apex after blank check
    // =========================================================================
    @AuraEnabled global String  customerAccountId;
    @AuraEnabled global String  customerName;
    @AuraEnabled global String  customerPhone;
    @AuraEnabled global String  customerEmail;

    // =========================================================================
    // SECTION 7 - Account Dealer (auto-filled)
    // dealerAccountId declared as String - cast to Id in Apex after blank check
    // =========================================================================
    @AuraEnabled global String  dealerAccountId;
    @AuraEnabled global String  dealerName;
    @AuraEnabled global String  dealerCode;
    @AuraEnabled global String  dealerPhone;
    @AuraEnabled global String  dealerCity;
    @AuraEnabled global String  dealerState;

    // =========================================================================
    // SECTION 8 - User-entered (warrantyClaimForm LWC Step 1)
    // =========================================================================
    @AuraEnabled global Decimal currentOdometerReading;
    @AuraEnabled global String  breakdownLocation;
    @AuraEnabled global String  affectedComponent;
    @AuraEnabled global String  faultCode;
    @AuraEnabled global String  faultDescription;
    @AuraEnabled global Boolean isVehicleDrivable;
    @AuraEnabled global String  repairTypeRequested;
    @AuraEnabled global String  preferredContactMethod;
    @AuraEnabled global String  additionalNotes;
    // Agentforce context fields - accepted to prevent variable not found errors
    @AuraEnabled global Boolean servicedAtAuthorisedDealer;
    @AuraEnabled global String  lastServiceDate;
    @AuraEnabled global Decimal lastServiceOdometerReading;

    // =========================================================================
    // SECTION 9 - Optional (Steps 2 and 3)
    // =========================================================================
    @AuraEnabled global String  claimItemsJson;
    @AuraEnabled global String  noteTitle;
    @AuraEnabled global String  noteBody;

    // =========================================================================
    // SECTION 10 - CLT control gate
    // =========================================================================
    @AuraEnabled global String  submitRequested;
}