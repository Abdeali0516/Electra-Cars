public with sharing class WarrantyEligibilityService {

    // ─────────────────────────────────────────────
    // Result wrapper returned to Agent Action + LWC
    // ─────────────────────────────────────────────
    public class EligibilityResult {
        @AuraEnabled public Boolean isEligible;
        @AuraEnabled public String  status;           // ELIGIBLE | ELIGIBLE_VIA_CONTRACT | EXPIRED | NO_WARRANTY | NOT_FOUND | MILEAGE_EXCEEDED | ERROR
        @AuraEnabled public String  message;

        // Vehicle identity (all confirmed from Vehicle CSV export)
        @AuraEnabled public String  vehicleId;        // Vehicle.Id
        @AuraEnabled public String  assetId;          // Vehicle.AssetId
        @AuraEnabled public String  currentOwnerId;   // Vehicle.CurrentOwnerId (Account)
        @AuraEnabled public String  vehicleName;      // Toyota Fortuner 2024
        @AuraEnabled public String  chassisNumber;    // MHFAB1234K6001234
        @AuraEnabled public String  stockCode;        // STK-TY-FTN-001245
        @AuraEnabled public String  vehicleStatus;    // At Dealer Location
        @AuraEnabled public String  engineNumber;     // 1GD-FTV-9876543
        @AuraEnabled public String  exteriorColor;    // Super White
        @AuraEnabled public String  interiorColor;    // Black
        @AuraEnabled public String  gearBoxType;      // 6-Speed Automatic
        @AuraEnabled public String  fuelSource;
        @AuraEnabled public String  vin;              // VehicleIdentificationNumber

        // Dates (confirmed from CSV)
        @AuraEnabled public String  manufacturedDate; // 2024-04-02
        @AuraEnabled public String  lastServiceDate;  // 2025-01-15
        @AuraEnabled public String  warrantyStartDate;
        @AuraEnabled public String  warrantyEndDate;

        // Warranty / contract counters
        @AuraEnabled public Integer activeServiceContracts;
        @AuraEnabled public Integer activeWarrantyCount;

        // Owner (from Contact linked via CurrentOwnerId Account)
        @AuraEnabled public String  ownerName;
        @AuraEnabled public String  ownerEmail;
        @AuraEnabled public String  ownerPhone;
        @AuraEnabled public String  ownerCity;
        @AuraEnabled public String  ownerState;
        @AuraEnabled public String  dealerName;

        // History
        @AuraEnabled public Integer claimCount;

        // Active warranty types
        @AuraEnabled public List<WarrantyProfile.WarrantyItem> warranties;
    }

    // ─────────────────────────────────────────────
    // Main eligibility check — called by Agent Action
    // and directly by LWC via @AuraEnabled
    // ─────────────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static EligibilityResult checkEligibility(String vinNumber, Decimal currentMileage) {
        EligibilityResult result = new EligibilityResult();

        try {
            // ── Step 1: Query Vehicle by VIN ──────────────────────────────
            // VehicleIdentificationNumber confirmed as the VIN field (CSV)
            // ManufacturerWarrantyStartDt / ManufacturerWarrantyEndDate confirmed fields
            // ActiveServiceContractCount = 1 in CSV (used as fallback)
            List<Vehicle> vehicles = [
                SELECT Id,
                       Name,
                       VehicleIdentificationNumber,
                       ChassisNumber,
                       StockCode,
                       Status,
                       EngineNumber,
                       ExteriorColor,
                       InteriorColor,
                       GearBoxType,
                       FuelSource,
                       ManufacturedDate,
                       LastServiceDate,
                       ManufacturerWarrantyStartDt,
                       ManufacturerWarrantyEndDate,
                       ActiveWarrantyCount,
                       ActiveServiceContractCount,
                       CurrentOwnerId,
                       AssetId
                FROM Vehicle
                WHERE VehicleIdentificationNumber = :vinNumber
                LIMIT 1
            ];

            if (vehicles.isEmpty()) {
                result.isEligible = false;
                result.status     = 'NOT_FOUND';
                result.message    = 'No vehicle found for VIN: ' + vinNumber
                                  + '. Please verify the VIN number.';
                return result;
            }

            Vehicle v = vehicles[0];

            // ── Step 2: Populate vehicle fields ─────────────────────────────
            result.vehicleId     = v.Id;
            result.assetId       = v.AssetId;
            result.currentOwnerId = v.CurrentOwnerId;
            result.vin           = v.VehicleIdentificationNumber;
            result.vehicleName   = v.Name;
            result.chassisNumber = v.ChassisNumber;
            result.stockCode     = v.StockCode;
            result.vehicleStatus = v.Status;
            result.engineNumber  = v.EngineNumber;
            result.exteriorColor = v.ExteriorColor;
            result.interiorColor = v.InteriorColor;
            result.gearBoxType   = v.GearBoxType;
            result.fuelSource    = v.FuelSource;
            result.manufacturedDate  = v.ManufacturedDate  != null ? String.valueOf(v.ManufacturedDate)  : null;
            result.lastServiceDate   = v.LastServiceDate   != null ? String.valueOf(v.LastServiceDate)   : null;
            result.activeServiceContracts = v.ActiveServiceContractCount != null
                                            ? Integer.valueOf(v.ActiveServiceContractCount) : 0;
            result.activeWarrantyCount    = v.ActiveWarrantyCount != null
                                            ? Integer.valueOf(v.ActiveWarrantyCount) : 0;

            // ── Step 2b: Fetch active AssetWarranty records ─────────────────
            result.warranties = new List<WarrantyProfile.WarrantyItem>();
            if (v.AssetId != null) {
                for (AssetWarranty aw : [
                    SELECT WarrantyType, EndDate,
                           WarrantyTerm.UsageCovered, WarrantyTerm.UsageCoveredUomId
                    FROM   AssetWarranty
                    WHERE  AssetId    = :v.AssetId
                      AND  StartDate <= TODAY
                      AND  EndDate   >= TODAY
                    ORDER BY EndDate ASC
                ]) {
                    WarrantyProfile.WarrantyItem wi = new WarrantyProfile.WarrantyItem();
                    wi.warrantyType = aw.WarrantyType;
                    wi.endDate      = aw.EndDate != null ? String.valueOf(aw.EndDate) : null;
                    wi.mileageLimit = (aw.WarrantyTerm != null && aw.WarrantyTerm.UsageCovered != null)
                                      ? aw.WarrantyTerm.UsageCovered : null;
                    result.warranties.add(wi);
                }
            }

            // ── Step 3: Warranty eligibility check ──────────────────────────
            // Primary: ManufacturerWarrantyEndDate
            // Fallback: ActiveServiceContractCount > 0 (= 1 in CSV)
            if (v.ManufacturerWarrantyEndDate != null) {
                result.warrantyStartDate = v.ManufacturerWarrantyStartDt != null
                                           ? String.valueOf(v.ManufacturerWarrantyStartDt) : null;
                result.warrantyEndDate   = String.valueOf(v.ManufacturerWarrantyEndDate);

                if (v.ManufacturerWarrantyEndDate < Date.today()) {
                    result.isEligible = false;
                    result.status     = 'EXPIRED';
                    result.message    = 'Manufacturer warranty expired on '
                                      + v.ManufacturerWarrantyEndDate.format() + '.';
                    return result;
                }

                result.isEligible = true;
                result.status     = 'ELIGIBLE';
                result.message    = 'Vehicle is warranty eligible until '
                                  + v.ManufacturerWarrantyEndDate.format() + '.';

            } else if (v.ActiveServiceContractCount != null && v.ActiveServiceContractCount > 0) {
                // Fallback: warranty dates not set but active service contract exists
                result.isEligible    = true;
                result.status        = 'ELIGIBLE_VIA_CONTRACT';
                result.warrantyStartDate = null;
                result.warrantyEndDate   = null;
                result.message = 'Manufacturer warranty dates not configured. '
                               + 'Vehicle has ' + Integer.valueOf(v.ActiveServiceContractCount)
                               + ' active service contract(s). Eligible to proceed.';
            } else {
                result.isEligible = false;
                result.status     = 'NO_WARRANTY';
                result.message    = 'No active warranty or service contract found for this vehicle.';
                return result;
            }

            // ── Step 4: Mileage check (dealer-provided — LastOdometerReading is null in CSV) ──
            if (currentMileage != null && currentMileage > 100000) {
                result.isEligible = false;
                result.status     = 'MILEAGE_EXCEEDED';
                result.message    = 'Reported mileage (' + currentMileage
                                  + ' km) exceeds warranty mileage limit (100,000 km).';
                return result;
            }

            // ── Step 5: Owner lookup via CurrentOwnerId (Account) ───────────
            if (v.CurrentOwnerId != null) {
                // Fetch dealer account name
                List<Account> dealers = [
                    SELECT Id, Name
                    FROM Account
                    WHERE Id = :v.CurrentOwnerId
                    LIMIT 1
                ];
                if (!dealers.isEmpty()) {
                    result.dealerName = dealers[0].Name;
                }

                // Fetch primary contact under this account
                List<Contact> contacts = [
                    SELECT Id, FirstName, LastName,
                           Email, Phone,
                           MailingCity, MailingState
                    FROM Contact
                    WHERE AccountId = :v.CurrentOwnerId
                    ORDER BY CreatedDate ASC
                    LIMIT 1
                ];
                if (!contacts.isEmpty()) {
                    Contact c     = contacts[0];
                    result.ownerName  = c.FirstName + ' ' + c.LastName;
                    result.ownerEmail = c.Email;
                    result.ownerPhone = c.Phone;
                    result.ownerCity  = c.MailingCity;
                    result.ownerState = c.MailingState;
                }
            }

            // ── Step 6: Prior claim count via AccountId ──────────────────────
            // InsuredAssetId not usable (links to InsurancePolicyAsset, no Vehicle/Asset FK)
            // AccountId confirmed on WarrantyClaim
            if (v.CurrentOwnerId != null) {
                result.claimCount = [
                    SELECT COUNT()
                    FROM Claim
                    WHERE AccountId = :v.CurrentOwnerId
                ];
            } else {
                result.claimCount = 0;
            }

        } catch (Exception e) {
            result.isEligible = false;
            result.status     = 'ERROR';
            result.message    = 'Eligibility check failed: ' + e.getMessage();
        }
	
        return result;
    }
}