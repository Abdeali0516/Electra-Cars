global class AgentWarrantyAction {

    // ─────────────────────────────────────────────
    // Input from Agentforce conversation
    // ─────────────────────────────────────────────
    
    @JsonAccess(serializable='always' deserializable='always')
    global class ActionInput {
        @InvocableVariable(label='VIN Number' required=true)
        public String vinNumber;

        @InvocableVariable(label='Current Mileage in KM')
        public Decimal currentMileage;

        @InvocableVariable(label='Dealer Account Id')
        public String dealerId;
    }

    // ─────────────────────────────────────────────
    // Output back to Agentforce
    // ────────────────────────────────────────────
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
         @InvocableVariable(label='Warranty Profile')
        public WarrantyProfile warrantyProfile;
    }
   

    // ─────────────────────────────────────────────
    // Invocable method — registered as Agent Action
    // ─────────────────────────────────────────────
    @InvocableMethod(
        label='Check Warranty Eligibility'
        description='Validates vehicle warranty using VIN and mileage. Creates a draft WarrantyClaim on eligibility. Returns customer profile JSON for LWC display.'
    )
    public static List<ActionOutput> checkEligibility(List<ActionInput> inputs) {
        List<ActionOutput> outputs = new List<ActionOutput>();

        for (ActionInput input : inputs) {
            ActionOutput output = new ActionOutput();

            WarrantyEligibilityService.EligibilityResult res =
                WarrantyEligibilityService.checkEligibility(
                    input.vinNumber, input.currentMileage
                );

            output.isEligible   = res.isEligible;
            output.statusCode   = res.status;
            output.agentMessage = res.message;

            // ── Create draft claim ───────────────────────────────────────
            if (res.isEligible) {
                try {
                    Claim claim = new Claim(
                        AccountId      = res.currentOwnerId,
                        Status         = 'Draft',
                        ClaimType      = 'Warranty',
                        InitiationDate = Date.today(),
                        ClaimReason    = 'Part Replacement',
                        IsDrivable     = true,
                        Summary        = 'VIN: '        + res.vin
                                       + ' | Vehicle: ' + res.vehicleName
                                       + ' | Mileage: ' + input.currentMileage
                    );
                    insert claim;
                    output.warrantyClaimId = claim.Id;
                } catch (Exception e) {
                    System.debug('Claim insert failed: ' + e.getMessage());
                }
            }

            // ── Build structured WarrantyProfile ─────────────────────────
            WarrantyProfile wp   = new WarrantyProfile();
            wp.vin               = res.vin;
            wp.vehicleId         = res.vehicleId;
            wp.vehicleName       = res.vehicleName;
            wp.chassisNumber     = res.chassisNumber;
            wp.stockCode         = res.stockCode;
            wp.vehicleStatus     = res.vehicleStatus;
            wp.engineNumber      = res.engineNumber;
            wp.exteriorColor     = res.exteriorColor;
            wp.interiorColor     = res.interiorColor;
            wp.gearBoxType       = res.gearBoxType;
            wp.manufacturedDate  = res.manufacturedDate;
            wp.lastServiceDate   = res.lastServiceDate;
            wp.warrantyStatus    = res.status;
            wp.warrantyStart     = res.warrantyStartDate;
            wp.warrantyEnd       = res.warrantyEndDate;
            wp.activeContracts   = res.activeServiceContracts;
            wp.activeWarranty    = res.activeWarrantyCount;
            wp.ownerName         = res.ownerName;
            wp.ownerEmail        = res.ownerEmail;
            wp.ownerPhone        = res.ownerPhone;
            wp.ownerCity         = res.ownerCity;
            wp.ownerState        = res.ownerState;
            wp.dealerName        = res.dealerName;
            wp.claimCount        = res.claimCount;
            wp.claimId           = output.warrantyClaimId;
            wp.reportedMileage   = input.currentMileage;
            wp.warranties        = res.warranties;

            output.warrantyProfile = wp;
            outputs.add(output);
            System.debug('outputs: '+outputs);
        }
        return outputs;
    }

    // ─────────────────────────────────────────────
    // Helper: claim summary string
    // ─────────────────────────────────────────────
    private static String buildSummary(
        WarrantyEligibilityService.EligibilityResult res,
        Decimal mileage
    ) {
        return 'VIN: '         + res.vin
             + ' | Vehicle: '  + res.vehicleName
             + ' | Chassis: '  + res.chassisNumber
             + ' | Stock: '    + res.stockCode
             + ' | Mileage: '  + (mileage != null ? String.valueOf(mileage) + ' km' : 'Not provided')
             + ' | Status: '   + res.status;
    }

    // ─────────────────────────────────────────────
    // Helper: JSON profile for LWC consumption
    // ─────────────────────────────────────────────
    private static String buildProfileJson(
        WarrantyEligibilityService.EligibilityResult res,
        ActionInput input,
        String claimId
    ) {
        Map<String, Object> profile = new Map<String, Object>{
            // Vehicle identity
            'vin'              => res.vin,
            'vehicleId'        => res.vehicleId,
            'vehicleName'      => res.vehicleName,
            'chassisNumber'    => res.chassisNumber,
            'stockCode'        => res.stockCode,
            'vehicleStatus'    => res.vehicleStatus,
            'engineNumber'     => res.engineNumber,
            'exteriorColor'    => res.exteriorColor,
            'interiorColor'    => res.interiorColor,
            'gearBoxType'      => res.gearBoxType,
            'fuelSource'       => res.fuelSource,
            // Dates
            'manufacturedDate' => res.manufacturedDate,
            'lastServiceDate'  => res.lastServiceDate,
            'warrantyStart'    => res.warrantyStartDate,
            'warrantyEnd'      => res.warrantyEndDate,
            // Warranty
            'warrantyStatus'   => res.status,
            'activeContracts'  => res.activeServiceContracts,
            'activeWarranty'   => res.activeWarrantyCount,
            // Owner
            'ownerName'        => res.ownerName,
            'ownerEmail'       => res.ownerEmail,
            'ownerPhone'       => res.ownerPhone,
            'ownerCity'        => res.ownerCity,
            'ownerState'       => res.ownerState,
            'dealerName'       => res.dealerName,
            // Claim
            'claimCount'       => res.claimCount,
            'claimId'          => claimId,
            'reportedMileage'  => input.currentMileage
        };
        return JSON.serialize(profile);
    }
}