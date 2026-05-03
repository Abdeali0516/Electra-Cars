global class VehicleWarrantyAction {

    // ── Input ────────────────────────────────────────────────────────────────
    @JsonAccess(serializable='always' deserializable='always')
    global class ActionInput {
        @InvocableVariable(label='VIN Number' required=true)
        public String vinNumber;

        @InvocableVariable(label='Current Mileage in KM')
        public Decimal currentMileage;
    }

    // ── Output ───────────────────────────────────────────────────────────────
    @JsonAccess(serializable='always' deserializable='always')
    global class ActionOutput {
        @InvocableVariable(label='Is Eligible')
        public Boolean isEligible;

        @InvocableVariable(label='Status Code')
        public String statusCode;

        @InvocableVariable(label='Agent Response Message')
        public String agentMessage;

        @InvocableVariable(label='Warranty Claim Record Id')
        public String warrantyClaimId;

        @AuraEnabled
        @InvocableVariable(label='Vehicle Warranty Profile')
        public VehicleWarrantyProfile profile;
    }

    // ── Profile type — registered as Lightning Type via vehicleWarrantyOutput ─
    @JsonAccess(serializable='always' deserializable='always')
    global class VehicleWarrantyProfile {
        @AuraEnabled public String  vin;
        @AuraEnabled public String  vehicleId;
        @AuraEnabled public String  vehicleName;
        @AuraEnabled public String  exteriorColor;
        @AuraEnabled public String  chassisNumber;
        @AuraEnabled public String  stockCode;
        @AuraEnabled public String  vehicleStatus;
        @AuraEnabled public String  engineNumber;
        @AuraEnabled public String  interiorColor;
        @AuraEnabled public String  gearBoxType;
        @AuraEnabled public String  manufacturedDate;
        @AuraEnabled public String  lastServiceDate;
        @AuraEnabled public String  warrantyStatus;
        @AuraEnabled public String  warrantyStart;
        @AuraEnabled public String  warrantyEnd;
        @AuraEnabled public Integer activeContracts;
        @AuraEnabled public Integer activeWarranty;
        @AuraEnabled public String  ownerName;
        @AuraEnabled public String  ownerEmail;
        @AuraEnabled public String  ownerPhone;
        @AuraEnabled public String  ownerCity;
        @AuraEnabled public String  ownerState;
        @AuraEnabled public String  dealerName;
        @AuraEnabled public Integer claimCount;
        @AuraEnabled public String  claimId;
        @AuraEnabled public Decimal reportedMileage;
        @AuraEnabled public List<WarrantyLine> warranties;
    }

    // ── Individual warranty line ──────────────────────────────────────────────
    @JsonAccess(serializable='always' deserializable='always')
    global class WarrantyLine {
        @AuraEnabled public String  warrantyType;
        @AuraEnabled public String  endDate;
        @AuraEnabled public Decimal mileageLimit;
    }

    // ── Invocable method ─────────────────────────────────────────────────────
    @InvocableMethod(
        label='Check Vehicle Warranty'
        description='Validates vehicle warranty via VIN and mileage. Creates a draft Claim on eligibility. Returns VehicleWarrantyProfile for LWC card display.'
    )
    public static List<ActionOutput> checkWarranty(List<ActionInput> inputs) {
        List<ActionOutput> results = new List<ActionOutput>();

        for (ActionInput inp : inputs) {
            ActionOutput out = new ActionOutput();

            WarrantyEligibilityService.EligibilityResult res =
                WarrantyEligibilityService.checkEligibility(inp.vinNumber, inp.currentMileage);

            out.isEligible   = res.isEligible;
            out.statusCode   = res.status;
            out.agentMessage = res.message;

            /*if (res.isEligible) {
                try {
                    Claim cl = new Claim(
                        AccountId      = res.currentOwnerId,
                        Status         = 'Draft',
                        ClaimType      = 'Warranty',
                        InitiationDate = Date.today(),
                        ClaimReason    = 'Part Replacement',
                        IsDrivable     = true,
                        Summary        = 'VIN: ' + res.vin
                                       + ' | Vehicle: ' + res.vehicleName
                                       + ' | Mileage: ' + inp.currentMileage
                    );
                    insert cl;
                    out.warrantyClaimId = cl.Id;
                } catch (Exception e) {
                    System.debug('Claim insert failed: ' + e.getMessage());
                }
            }*/

            VehicleWarrantyProfile vwp = new VehicleWarrantyProfile();
            vwp.vin             = res.vin;
            vwp.vehicleId       = res.vehicleId;
            vwp.vehicleName     = res.vehicleName;
            vwp.exteriorColor   = res.exteriorColor;
            vwp.chassisNumber   = res.chassisNumber;
            vwp.stockCode       = res.stockCode;
            vwp.vehicleStatus   = res.vehicleStatus;
            vwp.engineNumber    = res.engineNumber;
            vwp.interiorColor   = res.interiorColor;
            vwp.gearBoxType     = res.gearBoxType;
            vwp.manufacturedDate = res.manufacturedDate;
            vwp.lastServiceDate  = res.lastServiceDate;
            vwp.warrantyStatus  = res.status;
            vwp.warrantyStart   = res.warrantyStartDate;
            vwp.warrantyEnd     = res.warrantyEndDate;
            vwp.activeContracts = res.activeServiceContracts;
            vwp.activeWarranty  = res.activeWarrantyCount;
            vwp.ownerName       = res.ownerName;
            vwp.ownerEmail      = res.ownerEmail;
            vwp.ownerPhone      = res.ownerPhone;
            vwp.ownerCity       = res.ownerCity;
            vwp.ownerState      = res.ownerState;
            vwp.dealerName      = res.dealerName;
            vwp.claimCount      = res.claimCount;
            vwp.claimId         = out.warrantyClaimId;
            vwp.reportedMileage = inp.currentMileage;

            vwp.warranties = new List<WarrantyLine>();
            if (res.assetId != null) {
                for (AssetWarranty aw : [
                    SELECT WarrantyType, EndDate,
                           WarrantyTerm.UsageCovered, WarrantyTerm.UsageCoveredUomId
                    FROM   AssetWarranty
                    WHERE  AssetId    = :res.assetId
                      AND  StartDate <= TODAY
                      AND  EndDate   >= TODAY
                    ORDER BY EndDate ASC
                ]) {
                    WarrantyLine wl   = new WarrantyLine();
                    wl.warrantyType   = aw.WarrantyType;
                    wl.endDate        = aw.EndDate != null ? String.valueOf(aw.EndDate) : null;
                    wl.mileageLimit   = (aw.WarrantyTerm != null && aw.WarrantyTerm.UsageCovered != null)
                                        ? aw.WarrantyTerm.UsageCovered : null;
                    vwp.warranties.add(wl);
                }
            }

            out.profile = vwp;
            results.add(out);
        }
        return results;
    }
}